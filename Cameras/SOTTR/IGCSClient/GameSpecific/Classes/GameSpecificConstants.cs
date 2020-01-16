////////////////////////////////////////////////////////////////////////////////////////////////////////
// Part of Injectable Generic Camera System
// Copyright(c) 2020, Frans Bouma
// All rights reserved.
// https://github.com/FransBouma/InjectableGenericCameraSystem
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met :
//
//  * Redistributions of source code must retain the above copyright notice, this
//	  list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and / or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED.IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
////////////////////////////////////////////////////////////////////////////////////////////////////////

using System.Windows.Forms;

namespace IGCSClient.GameSpecific.Classes
{
	internal static class GameSpecificConstants
	{
		public const string ClientWindowTitle = "Shadow of the Tomb Raider tools";
		public const string CameraVersion = "1.0.6";
		public const string CameraCredits = "Otis_Inf";
		public const bool HotsamplingRequiresEXITSIZEMOVE = false;
	}


	internal static class GameSpecificSettingDefaults
	{
		public const float FastMovementMultiplier = 5.0f;
		public const float SlowMovementMultiplier = 0.1f;
		public const float UpMovementMultiplier = 0.7f;
		public const float MovementSpeed = 1.0f;
		public const int CameraControlDevice = 2;
		public const float RotationSpeed = 0.01f;
		public const bool InvertYLookDirection = false;
		public const float FoVZoomSpeed = 0.001f;
	}


	internal static class GameSpecificKeyBindingDefaults
	{
		public const int BlockInputToGameDefault = (int)Keys.Decimal;
		public const int EnableDisableCameraDefault = (int)Keys.Insert;
		public const int DecreaseFoVDefault = (int)Keys.Subtract;
		public const int IncreaseFoVDefault = (int)Keys.Add;
		public const int ResetFoVDefault = (int)Keys.Multiply;
		public const int LockUnlockCameraMovementDefault = (int)Keys.Home;
		public const int MoveCameraLeftDefault = (int)Keys.NumPad4;
		public const int MoveCameraRightDefault = (int)Keys.NumPad6;
		public const int MoveCameraForwardDefault = (int)Keys.NumPad8;
		public const int MoveCameraBackwardDefault = (int)Keys.NumPad5;
		public const int MoveCameraUpDefault = (int)Keys.NumPad7;
		public const int MoveCameraDownDefault = (int)Keys.NumPad9;
		public const int RotateCameraUpDefault = (int)Keys.Up;
		public const int RotateCameraDownDefault = (int)Keys.Down;
		public const int RotateCameraLeftDefault = (int)Keys.Left;
		public const int RotateCameraRightDefault = (int)Keys.Right;
		public const int TiltCameraLeftDefault = (int)Keys.NumPad1;
		public const int TiltCameraRightDefault = (int)Keys.NumPad3;
		public const int ToggleHUDDefault = (int)Keys.Delete;
		public const int PauseUnpauseGameDefault = (int)Keys.NumPad0;
	}
}