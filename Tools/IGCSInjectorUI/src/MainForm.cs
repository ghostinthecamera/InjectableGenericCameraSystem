﻿using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Configuration;
using System.Threading;

namespace IGCSInjectorUI
{
    public partial class MainForm : Form
    {
		// Use a static string, as we need to read this at injecting time and we can't have the JIT optimizer cleaning up right after the call,
		// as the value is written to process memory using a P/Invoke which can be handled asynchronously. If the JIT optimizes away the string right after the call
		// the filename write is insufficient and things fail. 
		public static string DllPathNameToInject = string.Empty;

		private static string RecentlyUsedFilename = "IGCSInjectorRecentlyUsed.txt";
		private static string IGCSSettingsFolder = "IGCS";
		private static int NumberOfCacheEntriesToKeep = 100;

		private Process _selectedProcess;
		private Dictionary<string, DllCacheData> _recentProcessesWithDllsUsed;		// key: process name (blabla.exe), value: dll name (full path) & DateTime last used.
		private string _defaultProcessName;
		private string _defaultDllName;

        public MainForm()
        {
            InitializeComponent();
			_selectedProcess = null;
			_recentProcessesWithDllsUsed = new Dictionary<string, DllCacheData>();
		}


		protected override void OnLoad(EventArgs e)
		{
			base.OnLoad(e);
			
			LoadDefaultNamesFromConfigFile();
			FindDefaultProcess();

			try
			{
				LoadRecentProcessList();
			}
			catch
			{
				// ignore, as we can't do much about it anyway... 
			}

			DisplayProcessInForm();
			DisplayVersionInForm();
		}


		protected override void OnClosing(CancelEventArgs e)
		{
			base.OnClosing(e);
			SaveRecentProcessList();
		}


		private void LoadRecentProcessList()
		{
			var fileName = Path.Combine(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), IGCSSettingsFolder), RecentlyUsedFilename);
			if(!File.Exists(fileName))
			{
				return;
			}
			// format: 
			// processname1|dllname1|Ticks
			// processname2|dllname1|Ticks
			// processname3|dllname2|Ticks
			// ...
			// example:
			// mygame.exe|..\..\mygamecameratools.dll
			// mygame2.exe|unlocker.dll
			var allLines = File.ReadAllLines(fileName);
			foreach(var line in allLines)
			{
				var parts = line.Split('|');
				if(parts.Length!=3)
				{
					continue;
				}
				_recentProcessesWithDllsUsed[parts[0]] = new DllCacheData(parts[1], new DateTime(Convert.ToInt64(parts[2])));
			}
		}


		private void SaveRecentProcessList()
		{
			if(_recentProcessesWithDllsUsed.Count<=0)
			{
				return;
			}
			// trim list if there are more than the max
			if(_recentProcessesWithDllsUsed.Count > NumberOfCacheEntriesToKeep)
			{
				// keep the most recent 100. 
				var mostRecent = _recentProcessesWithDllsUsed.OrderByDescending(kvp=>kvp.Value.LastUsedDate).Take(NumberOfCacheEntriesToKeep).Select(kvp=>kvp.Key).ToList();
				// remove the rest. 
				var toRemove = _recentProcessesWithDllsUsed.Keys.Except(mostRecent).ToList();
				foreach(var key in toRemove)
				{
					_recentProcessesWithDllsUsed.Remove(key);
				}
			}
			var folderName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), IGCSSettingsFolder);
			if(!Directory.Exists(folderName))
			{
				Directory.CreateDirectory(folderName);
			}
			var fileName = Path.Combine(folderName, RecentlyUsedFilename);
			var linesToWrite = _recentProcessesWithDllsUsed.Select(kvp=>kvp.Key + "|" + kvp.Value.DllName + "|" + kvp.Value.LastUsedDate.Ticks);
			File.WriteAllLines(fileName, linesToWrite);
		}


		private void FindDefaultProcess()
		{
			if(string.IsNullOrWhiteSpace(_defaultProcessName))
			{
				return;
			}
			var currentProcess = Process.GetCurrentProcess();
			_selectedProcess = Process.GetProcesses().FirstOrDefault(p=>p.SessionId == currentProcess.SessionId && !string.IsNullOrEmpty(p.MainWindowTitle) && 
																		p.MainModule.ModuleName.ToLowerInvariant()==_defaultProcessName);
		}


		private void LoadDefaultNamesFromConfigFile()
		{
			_defaultDllName = ConfigurationManager.AppSettings["defaultDllName"] ?? string.Empty;
			_defaultProcessName = (ConfigurationManager.AppSettings["defaultProcessName"] ?? string.Empty).ToLowerInvariant();
			if(string.IsNullOrWhiteSpace(_defaultDllName))
			{
				return;
			}
			if(Path.GetExtension(_defaultDllName).ToLowerInvariant()!=".dll")
			{
				_defaultDllName = string.Empty;
				return;
			}
			// check if the default dll name contains a path. 
			var pathInDllName = Path.GetDirectoryName(_defaultDllName);
			if(pathInDllName==null)
			{
				// invalid
				_defaultDllName = string.Empty;
				return;
			}
			if(string.IsNullOrEmpty(pathInDllName))
			{
				_defaultDllName = Path.Combine(Environment.CurrentDirectory, _defaultDllName);
			}
			if(!File.Exists(_defaultDllName))
			{
				_defaultDllName = string.Empty;
				return;
			}
			// all clear. 
			_dllFilenameTextBox.Text = _defaultDllName;
		}


		private void DisplayVersionInForm()
		{
			this.Text += string.Format(" v{0}", this.GetType().Assembly.GetName().Version.ToString(3));
		}


		private void DisplayProcessInForm()
		{
			if(_selectedProcess==null)
			{
				_processNameTextBox.Text = "Please select a process...";
			}
			else
			{
				_processNameTextBox.Text = string.Format("({0}) {1} ({2})", _selectedProcess.Id,  _selectedProcess.MainModule.ModuleName, _selectedProcess.MainWindowTitle);
			}
		}


		private string GetAbsolutePathForDllName()
		{
			var toReturn = _dllFilenameTextBox.Text;
			if(string.IsNullOrWhiteSpace(toReturn))
			{
				return string.Empty;
			}
			if (Path.IsPathRooted(toReturn))
			{
				return toReturn;
			}
			var rawToReturn = Path.Combine(Environment.CurrentDirectory, toReturn);
			return Path.GetFullPath(rawToReturn).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
		}


		private void EnableDisableInjectButton()
		{
			_injectButton.Enabled = IsReadyToInject();
		}


		private bool IsReadyToInject()
		{
			var selectedFileExtension = (string.IsNullOrWhiteSpace(_dllFilenameTextBox.Text) ? string.Empty : Path.GetExtension(_dllFilenameTextBox.Text)) ?? string.Empty;
			return (_selectedProcess!=null && File.Exists(_dllFilenameTextBox.Text) && selectedFileExtension.ToLowerInvariant()==".dll");
		}

		private void _cancelButton_Click(object sender, EventArgs e)
		{
			this.DialogResult = DialogResult.Cancel;
			this.Close();
		}

		private void _processNameTextBox_TextChanged(object sender, EventArgs e)
		{
			EnableDisableInjectButton();
		}

		private void _dllFilenameTextBox_TextChanged(object sender, EventArgs e)
		{
			EnableDisableInjectButton();
		}

		private void _browseForDllButton_Click(object sender, EventArgs e)
		{
			_openDllToInjectDialog.InitialDirectory = Environment.CurrentDirectory;
			var result = _openDllToInjectDialog.ShowDialog(this);
			if(result==DialogResult.Cancel)
			{
				return;
			}
			_dllFilenameTextBox.Text = _openDllToInjectDialog.FileName;
			_mainToolTip.SetToolTip(_dllFilenameTextBox, _dllFilenameTextBox.Text);
		}

		private void _selectProcessButton_Click(object sender, EventArgs e)
		{
			using(var processSelector = new ProcessSelector(_recentProcessesWithDllsUsed.Keys.ToList()))
			{
				var result = processSelector.ShowDialog(this);
				if(result==DialogResult.Cancel)
				{
					return;
				}
				_selectedProcess = processSelector.SelectedProcess;
				DisplayProcessInForm();
				// pre-select the dll if there's no dll selected
				if(string.IsNullOrEmpty(_dllFilenameTextBox.Text))
				{
					if(_recentProcessesWithDllsUsed.TryGetValue(_selectedProcess.MainModule.ModuleName, out DllCacheData dllData))
					{
						_dllFilenameTextBox.Text = dllData.DllName;
					}
				}
			}
		}

		private void _injectButton_Click(object sender, EventArgs e)
		{
			if(!IsReadyToInject())
			{
				return;
			}
			// assume things are OK
			var injector = new DllInjector();
			MainForm.DllPathNameToInject = GetAbsolutePathForDllName();
			var result = injector.PerformInjection(_selectedProcess.Id);
			if(result)
			{
				// store dll with process name in recent list
				_recentProcessesWithDllsUsed[_selectedProcess.MainModule.ModuleName] = new DllCacheData(_dllFilenameTextBox.Text, DateTime.Now);
				MessageBox.Show(this, "Injection succeeded. Enjoy!", "Injection result", MessageBoxButtons.OK, MessageBoxIcon.Information);
				// we can now exit.
				this.Close();
			}
			else
			{
				MessageBox.Show(this, string.Format("Injection failed when performing:{0}{1}{0}The following error occurred:{0}{2}", 
											Environment.NewLine, injector.LastActionPerformed, new Win32Exception(injector.LastError).Message), "Injection result", 
											MessageBoxButtons.OK, MessageBoxIcon.Error);
			}
		}

		private void _aboutButton_Click(object sender, EventArgs e)
		{
			using(var aboutForm = new About())
			{
				aboutForm.ShowDialog(this);
			}
		}
	}
}
