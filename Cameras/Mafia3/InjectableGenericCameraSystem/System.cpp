﻿////////////////////////////////////////////////////////////////////////////////////////////////////////
// Part of Injectable Generic Camera System
// Copyright(c) 2017, Frans Bouma
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
#include "stdafx.h"
#include "System.h"
#include "Globals.h"
#include "Defaults.h"
#include "GameConstants.h"
#include "Gamepad.h"
#include "CameraManipulator.h"
#include "InterceptorHelper.h"
#include "InputHooker.h"
#include "input.h"
#include "CameraManipulator.h"
#include "GameImageHooker.h"

namespace IGCS
{
	using namespace IGCS::GameSpecific;

	System::System()
	{
	}


	System::~System()
	{
	}


	void System::start(LPBYTE hostBaseAddress, DWORD hostImageSize)
	{
		Globals::instance().systemActive(true);
		_hostImageAddress = (LPBYTE)hostBaseAddress;
		_hostImageSize = hostImageSize;
		Globals::instance().gamePad().setInvertLStickY(CONTROLLER_Y_INVERT);
		Globals::instance().gamePad().setInvertRStickY(CONTROLLER_Y_INVERT);
		displayHelp();
		initialize();		// will block till camera is found
		mainLoop();
	}


	// Core loop of the system
	void System::mainLoop()
	{
		while (Globals::instance().systemActive())
		{
			Sleep(FRAME_SLEEP);
			updateFrame();
		}
	}


	// updates the data and camera for a frame 
	void System::updateFrame()
	{
		handleUserInput();
		writeNewCameraValuesToCameraStructs();
	}
	

	void System::writeNewCameraValuesToCameraStructs()
	{
		if (!g_cameraEnabled)
		{
			return;
		}

		// calculate new camera values.
		XMVECTOR newLookQuaternion = _camera.calculateLookQuaternion();
		XMFLOAT3 currentCoords = GameSpecific::CameraManipulator::getCurrentCameraCoords();
		XMFLOAT3 newCoords = _camera.calculateNewCoords(currentCoords, newLookQuaternion);
		GameSpecific::CameraManipulator::writeNewCameraValuesToGameData(newCoords, newLookQuaternion);
	}


	void System::handleUserInput()
	{
		Globals::instance().gamePad().update();
		bool altPressed = Input::keyDown(VK_LMENU) || Input::keyDown(VK_RMENU);
		bool controlPressed = Input::keyDown(VK_RCONTROL);

		if (Input::keyDown(IGCS_KEY_HELP) && altPressed)
		{
			displayHelp();
		}
		if (Input::keyDown(IGCS_KEY_INVERT_Y_LOOK))
		{
			toggleYLookDirectionState();
			Sleep(350);		// wait for 350ms to avoid fast keyboard hammering
		}
		if (!_cameraStructFound)
		{
			// camera not found yet, can't proceed.
			return;
		}
		if (Input::keyDown(IGCS_KEY_CAMERA_ENABLE))
		{
			if (g_cameraEnabled)
			{
				// it's going to be disabled, make sure things are alright when we give it back to the host
				CameraManipulator::restoreOriginalCameraValues();
				toggleCameraMovementLockState(false);
				CameraManipulator::toggleHud((uint8_t)1);		// hud should be ON, so pass 1
			}
			else
			{
				// it's going to be enabled, so cache the original values before we enable it so we can restore it afterwards
				CameraManipulator::cacheOriginalCameraValues();
				_camera.resetAngles();
				displayControlDeviceName();
				CameraManipulator::toggleHud((uint8_t)0);		// hud should be OFF so pass 0
			}
			g_cameraEnabled = g_cameraEnabled == 0 ? (uint8_t)1 : (uint8_t)0;
			displayCameraState();
			Sleep(350);				// wait for 350ms to avoid fast keyboard hammering
		}
		if (Input::keyDown(IGCS_KEY_FOV_RESET) && Globals::instance().keyboardMouseControlCamera())
		{
			CameraManipulator::resetFoV();
		}
		if (Input::keyDown(IGCS_KEY_FOV_DECREASE) && Globals::instance().keyboardMouseControlCamera())
		{
			CameraManipulator::changeFoV(-DEFAULT_FOV_SPEED);
		}
		if (Input::keyDown(IGCS_KEY_FOV_INCREASE) && Globals::instance().keyboardMouseControlCamera())
		{
			CameraManipulator::changeFoV(DEFAULT_FOV_SPEED);
		}
		if (Input::keyDown(IGCS_KEY_TIMESTOP))
		{
			toggleTimestopState();
			Sleep(350);				// wait for 350ms to avoid fast keyboard hammering
		}
		if (Input::keyDown(IGCS_KEY_TOGGLE_HUD))
		{
			CameraManipulator::toggleHud();
			Sleep(350);				// wait for 350ms to avoid fast keyboard hammering
		}
		if (!g_cameraEnabled)
		{
			// camera is disabled. We simply disable all input to the camera movement, by returning now.
			return;
		}
		if (Input::keyDown(IGCS_KEY_CYCLE_DEVICE))
		{
			Globals::instance().cycleToNextControlDevice();
			displayControlDeviceName();
			Sleep(350);				// wait for 350ms to avoid fast keyboard hammering
		}

		_camera.resetMovement();
		float multiplier = altPressed ? FASTER_MULTIPLIER : controlPressed ? SLOWER_MULTIPLIER : 1.0f;
		if (Input::keyDown(IGCS_KEY_CAMERA_LOCK))
		{
			toggleCameraMovementLockState(!_cameraMovementLocked);
			Sleep(350);				// wait for 350ms to avoid fast keyboard hammering
		}
		if (_cameraMovementLocked)
		{
			// no movement allowed, simply return
			return;
		}

		handleKeyboardCameraMovement(multiplier);
		handleMouseCameraMovement(multiplier);
		handleGamePadMovement(multiplier);
	}


	void System::handleGamePadMovement(float multiplierBase)
	{
		auto gamePad = Globals::instance().gamePad();

		if (gamePad.isConnected())
		{
			if (Globals::instance().controllerControlsCamera())
			{
				float  multiplier = gamePad.isButtonPressed(IGCS_BUTTON_FASTER) ? FASTER_MULTIPLIER : gamePad.isButtonPressed(IGCS_BUTTON_SLOWER) ? SLOWER_MULTIPLIER : multiplierBase;

				vec2 rightStickPosition = gamePad.getRStickPosition();
				_camera.pitch(rightStickPosition.y * multiplier);
				_camera.yaw(rightStickPosition.x * multiplier);

				vec2 leftStickPosition = gamePad.getLStickPosition();
				_camera.moveUp((gamePad.getLTrigger() - gamePad.getRTrigger()) * multiplier);
				_camera.moveForward(leftStickPosition.y * multiplier);
				_camera.moveRight(leftStickPosition.x * multiplier);

				if (gamePad.isButtonPressed(IGCS_BUTTON_TILT_LEFT))
				{
					_camera.roll(multiplier);
				}
				if (gamePad.isButtonPressed(IGCS_BUTTON_TILT_RIGHT))
				{
					_camera.roll(-multiplier);
				}
				if (gamePad.isButtonPressed(IGCS_BUTTON_RESET_FOV))
				{
					CameraManipulator::resetFoV();
				}
				if (gamePad.isButtonPressed(IGCS_BUTTON_FOV_DECREASE))
				{
					CameraManipulator::changeFoV(-DEFAULT_FOV_SPEED);
				}
				if (gamePad.isButtonPressed(IGCS_BUTTON_FOV_INCREASE))
				{
					CameraManipulator::changeFoV(DEFAULT_FOV_SPEED);
				}
			}
			if (gamePad.isButtonPressed(IGCS_BUTTON_CYCLE_DEVICE))
			{
				Globals::instance().cycleToNextControlDevice();
				Sleep(350);				// wait for 350ms to avoid fast hammering
			}
		}
	}


	void System::handleMouseCameraMovement(float multiplier)
	{
		if (!Globals::instance().keyboardMouseControlCamera())
		{
			return;
		}
		long mouseDeltaX = Input::getMouseDeltaX();
		long mouseDeltaY = Input::getMouseDeltaY();
		if (abs(mouseDeltaY) > 1)
		{
			_camera.pitch(-(static_cast<float>(mouseDeltaY) * MOUSE_SPEED_CORRECTION * multiplier));
		}
		if (abs(mouseDeltaX) > 1)
		{
			_camera.yaw(static_cast<float>(mouseDeltaX) * MOUSE_SPEED_CORRECTION * multiplier);
		}
	}


	void System::handleKeyboardCameraMovement(float multiplier)
	{
		if (!Globals::instance().keyboardMouseControlCamera())
		{
			return;
		}
		if (Input::keyDown(IGCS_KEY_MOVE_FORWARD))
		{
			_camera.moveForward(multiplier);
		}
		if (Input::keyDown(IGCS_KEY_MOVE_BACKWARD))
		{
			_camera.moveForward(-multiplier);
		}
		if (Input::keyDown(IGCS_KEY_MOVE_RIGHT))
		{
			_camera.moveRight(multiplier);
		}
		if (Input::keyDown(IGCS_KEY_MOVE_LEFT))
		{
			_camera.moveRight(-multiplier);
		}
		if (Input::keyDown(IGCS_KEY_MOVE_UP))
		{
			_camera.moveUp(multiplier);
		}
		if (Input::keyDown(IGCS_KEY_MOVE_DOWN))
		{
			_camera.moveUp(-multiplier);
		}
		if (Input::keyDown(IGCS_KEY_ROTATE_DOWN))
		{
			_camera.pitch(-multiplier);
		}
		if (Input::keyDown(IGCS_KEY_ROTATE_UP))
		{
			_camera.pitch(multiplier);
		}
		if (Input::keyDown(IGCS_KEY_ROTATE_RIGHT))
		{
			_camera.yaw(multiplier);
		}
		if (Input::keyDown(IGCS_KEY_ROTATE_LEFT))
		{
			_camera.yaw(-multiplier);
		}
		if (Input::keyDown(IGCS_KEY_TILT_LEFT))
		{
			_camera.roll(multiplier);
		}
		if (Input::keyDown(IGCS_KEY_TILT_RIGHT))
		{
			_camera.roll(-multiplier);
		}
	}


	// Initializes system. Will block till camera struct is found.
	void System::initialize()
	{
		InputHooker::setInputHooks();
		Input::registerRawInput();
		GameSpecific::InterceptorHelper::initializeAOBBlocks(_hostImageAddress, _hostImageSize, _aobBlocks);
		GameSpecific::InterceptorHelper::setCameraStructInterceptorHook(_aobBlocks);
		GameSpecific::CameraManipulator::waitForCameraStructAddresses(_hostImageAddress);		// blocks till camera is found.
		GameSpecific::InterceptorHelper::setPostCameraStructHooks(_aobBlocks);
		GameSpecific::CameraManipulator::setTimestopAddress(Utils::calculateAbsoluteAddress(_aobBlocks[TIMESTOP_KEY], 4));

		// camera struct found, init our own camera object now and hook into game code which uses camera.
		_cameraStructFound = true;
		_camera.setPitch(INITIAL_PITCH_RADIANS);
		_camera.setRoll(INITIAL_ROLL_RADIANS);
		_camera.setYaw(INITIAL_YAW_RADIANS);
	}


	void System::toggleCameraMovementLockState(bool newValue)
	{
		if (_cameraMovementLocked == newValue)
		{
			// already in this state. Ignore
			return;
		}
		_cameraMovementLocked = newValue;
		Console::WriteLine(_cameraMovementLocked ? "Camera movement is locked" : "Camera movement is unlocked");
	}


	void System::displayCameraState()
	{
		Console::WriteLine(g_cameraEnabled ? "Camera enabled" : "Camera disabled");
	}


	void System::toggleYLookDirectionState()
	{
		_camera.toggleLookDirectionInverter();
		Console::WriteLine(_camera.lookDirectionInverter() < 0 ? "Y look direction is inverted" : "Y look direction is normal");
	}
	

	void System::toggleTimestopState()
	{
		_timeStopped = _timeStopped == 0 ? (uint8_t)1 : (uint8_t)0;
		Console::WriteLine(_timeStopped ? "Game paused" : "Game unpaused");
		CameraManipulator::setTimeStopValue(_timeStopped);
	}


	void System::displayControlDeviceName()
	{
		string deviceName = "Unknown";
		switch (Globals::instance().controlDevice())
		{
		case All:
			deviceName = "Keyboard / Mouse or Controller";
			break;
		case KeyboardMouse:
			deviceName = "Keyboard / Mouse";
			break;
		case Controller:
			deviceName = "Controller";
			break;
		}
		Console::WriteLine("Active camera controlling device: " + deviceName);
	}


	void System::displayHelp()
	{
						  //0         1         2         3         4         5         6         7
						  //01234567890123456789012345678901234567890123456789012345678901234567890123456789
		Console::WriteLine("---[IGCS Help]-----------------------------------------------------------------", CONSOLE_WHITE);
		Console::WriteLine("INS                                   : Enable/Disable camera");
		Console::WriteLine("HOME                                  : Lock/unlock camera movement");
		Console::WriteLine("ALT + rotate/move                     : Faster rotate / move");
		Console::WriteLine("Right-CTRL + rotate/move              : Slower rotate / move");
		Console::WriteLine("Controller Y-button + l/r-stick       : Faster rotate / move");
		Console::WriteLine("Controller X-button + l/r-stick       : Slower rotate / move");
		Console::WriteLine("Arrow up/down or mouse or r-stick     : Rotate camera up/down");
		Console::WriteLine("Arrow left/right or mouse or r-stick  : Rotate camera left/right");
		Console::WriteLine("Numpad 8/Numpad 5 or l-stick          : Move camera forward/backward");
		Console::WriteLine("Numpad 4/Numpad 6 or l-stick          : Move camera left / right");
		Console::WriteLine("Numpad 7/Numpad 9 or l/r-trigger      : Move camera up / down");
		Console::WriteLine("Numpad 1/Numpad 3 or d-pad left/right : Tilt camera left / right");
		Console::WriteLine("Numpad +/- or d-pad up/down           : Increase / decrease FoV (with freecam)");
		Console::WriteLine("Numpad * or controller B-button       : Reset FoV (with freecam)");
		Console::WriteLine("Numpad /                              : Toggle Y look direction");
		Console::WriteLine("Numpad . or controller Right Bumper   : Cycle through camera control devices");
		Console::WriteLine("Numpad 0                              : Toggle game pause");
		Console::WriteLine("END                                   : Toggle HUD");
		Console::WriteLine("ALT+H                                 : This help");
		Console::WriteLine("-------------------------------------------------------------------------------", CONSOLE_WHITE);
		Console::WriteLine(" Please read the enclosed readme.txt for the answers to your questions :)");
		Console::WriteLine("-------------------------------------------------------------------------------", CONSOLE_WHITE);
		// wait for 350ms to avoid fast keyboard hammering
		Sleep(350);
	}
}