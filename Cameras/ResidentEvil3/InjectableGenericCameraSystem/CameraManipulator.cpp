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
#include "stdafx.h"
#include "CameraManipulator.h"
#include "GameConstants.h"
#include "Globals.h"
#include "Camera.h"
#include "GameCameraData.h"
#include "MessageHandler.h"

using namespace DirectX;
using namespace std;

extern "C" {
	LPBYTE g_cameraStructAddress = nullptr;
	LPBYTE g_resolutionScaleAddress = nullptr;
	LPBYTE g_timestopStructAddress = nullptr;
	LPBYTE g_displayTypeStructAddress = nullptr;
	LPBYTE g_dofStructAddress = nullptr;
}

namespace IGCS::GameSpecific::CameraManipulator
{
	static GameCameraData _originalData;

	void updateCameraDataInGameData(Camera& camera)
	{
		if (!g_cameraEnabled)
		{
			return;
		}

		// calculate new camera values. We have two cameras, but they might not be available both, so we have to test before we do anything. 
		DirectX::XMVECTOR newLookQuaternion = camera.calculateLookQuaternion();
		DirectX::XMFLOAT3 currentCoords;
		DirectX::XMFLOAT3 newCoords;
		if (isCameraFound())
		{
			currentCoords = getCurrentCameraCoords();
			newCoords = camera.calculateNewCoords(currentCoords, newLookQuaternion);
			writeNewCameraValuesToGameData(newCoords, newLookQuaternion);
		}
	}

	
	void enableHotsampling()
	{
		if(nullptr==g_displayTypeStructAddress)
		{
			return;
		}
		BYTE* displayTypeInMemory = reinterpret_cast<BYTE*>(g_displayTypeStructAddress + DISPLAYTYPE_IN_STRUCT_OFFSET);
		*displayTypeInMemory = (BYTE)0;		// set to 0 (FIT)
	}
	

	void applySettingsToGameState()
	{
		Settings& currentSettings = Globals::instance().settings();
		if (nullptr != g_resolutionScaleAddress)
		{
			float* resolutionScaleInMemory = reinterpret_cast<float*>(g_resolutionScaleAddress + RESOLUTION_SCALE_IN_STRUCT_OFFSET);
			*resolutionScaleInMemory = Utils::clamp(currentSettings.resolutionScale, RESOLUTION_SCALE_MIN, RESOLUTION_SCALE_MAX, 1.0f);
		}
	}

	
	// This timestop is based on game speed. So if the game has to be paused, we will write a 0.00001f. If the game has to be unpaused, we'll write a 1.0f.
	void setTimeStopValue(bool pauseGame)
	{
		if (nullptr == g_timestopStructAddress)
		{
			return;
		}

		float* gameSpeedInMemory = reinterpret_cast<float*>(g_timestopStructAddress + TIMESTOP_FLOAT_OFFSET);
		*gameSpeedInMemory = pauseGame ? 0.0f : 1.0f;
	}

	
	void selectDoF(int dofToSelect)
	{
		if (nullptr != g_dofStructAddress)
		{
			int* dofSelectionInMemory = reinterpret_cast<int*>(g_dofStructAddress + DOF_SELECTOR_IN_STRUCT_OFFSET);
			*dofSelectionInMemory = dofToSelect;
		}
	}


	// Resets the FOV to the one it got when we enabled the camera
	void resetFoV()
	{
		if (nullptr == g_cameraStructAddress)
		{
			return;
		}
		float* fovAddress = reinterpret_cast<float*>(g_cameraStructAddress + FOV_IN_STRUCT_OFFSET);
		*fovAddress = _originalData._fov;
	}


	// changes the FoV with the specified amount
	void changeFoV(float amount)
	{
		if (nullptr == g_cameraStructAddress)
		{
			return;
		}
		float* fovAddress = reinterpret_cast<float*>(g_cameraStructAddress + FOV_IN_STRUCT_OFFSET);
		float newValue = *fovAddress + amount;
		if (newValue < 0.001f)
		{
			// clamp. 
			newValue = 0.001f;
		}
		*fovAddress = newValue;
	}


	float getCurrentFoV()
	{
		if (nullptr == g_cameraStructAddress)
		{
			return DEFAULT_FOV;
		}
		float* fovAddress = reinterpret_cast<float*>(g_cameraStructAddress + FOV_IN_STRUCT_OFFSET);
		return *fovAddress;
	}
	

	XMFLOAT3 getCurrentCameraCoords()
	{

		float* coordsInMemory = reinterpret_cast<float*>(g_cameraStructAddress + COORDS_IN_STRUCT_OFFSET);
		return XMFLOAT3(coordsInMemory[0], coordsInMemory[1], coordsInMemory[2]);
	}


	// newLookQuaternion: newly calculated quaternion of camera view space. Can be used to construct a 4x4 matrix if the game uses a matrix instead of a quaternion
	// newCoords are the new coordinates for the camera in worldspace.
	void writeNewCameraValuesToGameData(XMFLOAT3 newCoords, XMVECTOR newLookQuaternion)
	{
		if (!isCameraFound())
		{
			return;
		}

		XMFLOAT4 qAsFloat4;
		XMStoreFloat4(&qAsFloat4, newLookQuaternion);
		float* coordsInMemory = reinterpret_cast<float*>(g_cameraStructAddress + COORDS_IN_STRUCT_OFFSET);
		coordsInMemory[0] = newCoords.x;
		coordsInMemory[1] = newCoords.y;
		coordsInMemory[2] = newCoords.z;

		float* quaternionInMemory = reinterpret_cast<float*>(g_cameraStructAddress + QUATERNION_IN_STRUCT_OFFSET);
		quaternionInMemory[0] = qAsFloat4.x;
		quaternionInMemory[1] = qAsFloat4.y;
		quaternionInMemory[2] = qAsFloat4.z;
		quaternionInMemory[3] = qAsFloat4.w;
	}


	bool isCameraFound()
	{
		return nullptr != g_cameraStructAddress;
	}


	void displayCameraStructAddress()
	{
		MessageHandler::logDebug("Camera struct address: %p", (void*)g_cameraStructAddress);
	}


	void restoreGameCameraDataWithCachedData(GameCameraData& source)
	{
		if (!isCameraFound())
		{
			return;
		}
		source.RestoreData(reinterpret_cast<float*>(g_cameraStructAddress + QUATERNION_IN_STRUCT_OFFSET), reinterpret_cast<float*>(g_cameraStructAddress + COORDS_IN_STRUCT_OFFSET), 
						   reinterpret_cast<float*>(g_cameraStructAddress + FOV_IN_STRUCT_OFFSET));
	}


	void cacheGameCameraDataInCache(GameCameraData& destination)
	{
		if (!isCameraFound())
		{
			return;
		}
		destination.CacheData(reinterpret_cast<float*>(g_cameraStructAddress + QUATERNION_IN_STRUCT_OFFSET), reinterpret_cast<float*>(g_cameraStructAddress + COORDS_IN_STRUCT_OFFSET),
							  reinterpret_cast<float*>(g_cameraStructAddress + FOV_IN_STRUCT_OFFSET));
	}


	void restoreOriginalValuesAfterCameraDisable()
	{
		restoreGameCameraDataWithCachedData(_originalData);
	}


	void cacheOriginalValuesBeforeCameraEnable()
	{
		cacheGameCameraDataInCache(_originalData);
	}
}