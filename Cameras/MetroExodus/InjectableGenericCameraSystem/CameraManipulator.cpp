////////////////////////////////////////////////////////////////////////////////////////////////////////
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
#include "CameraManipulator.h"
#include "GameConstants.h"
#include "Console.h"
#include "Globals.h"

using namespace DirectX;
using namespace std;


namespace IGCS::GameSpecific::CameraManipulator
{
	static LPBYTE _cameraStructAddress = nullptr;
	static LPBYTE _fovAddress = nullptr;
	static float _originalMatrixData[16];
	static float _originalFoV;

	void setCameraStructAddress(LPBYTE structAddress)
	{
		_cameraStructAddress = structAddress;
	}

	void setFoVAddress(LPBYTE fovAddress)
	{
		_fovAddress = fovAddress;
	}

	

	XMFLOAT3 getCurrentCameraCoords()
	{
		float* coordsInMemory = reinterpret_cast<float*>(_cameraStructAddress + CAMERA_COORDS_IN_STRUCT_OFFSET);
		XMFLOAT3 currentCoords = XMFLOAT3(coordsInMemory);
		return currentCoords;
	}


	// newLookQuaternion: newly calculated quaternion of camera view space. Can be used to construct a 4x4 matrix if the game uses a matrix instead of a quaternion
	// newCoords are the new coordinates for the camera in worldspace.
	void writeNewCameraValuesToGameData(XMVECTOR newLookQuaternion, XMFLOAT3 newCoords)
	{
		// game uses a 4x3 matrix for look data. We have to calculate a rotation matrix from our quaternion and store the upper 3x3 matrix (_11-_33) in memory.
		XMMATRIX rotationMatrixPacked = XMMatrixRotationQuaternion(newLookQuaternion);
		XMFLOAT4X4 rotationMatrix;
		XMStoreFloat4x4(&rotationMatrix, rotationMatrixPacked);

		// 3x3 rotation part of matrix
		float* matrixInMemory = reinterpret_cast<float*>(_cameraStructAddress + CAMERA_MATRIX_IN_STRUCT_OFFSET);
		matrixInMemory[0] = rotationMatrix._11;
		matrixInMemory[1] = rotationMatrix._12;
		matrixInMemory[2] = rotationMatrix._13;
		// 3 is left empty
		matrixInMemory[4] = rotationMatrix._21;
		matrixInMemory[5] = rotationMatrix._22;
		matrixInMemory[6] = rotationMatrix._23;
		// 7 is left empty
		matrixInMemory[8] = rotationMatrix._31;
		matrixInMemory[9] = rotationMatrix._32;
		matrixInMemory[10] = rotationMatrix._33;

		// Coords
		float* coordsInMemory = reinterpret_cast<float*>(_cameraStructAddress + CAMERA_COORDS_IN_STRUCT_OFFSET);
		coordsInMemory[0] = newCoords.x;
		coordsInMemory[1] = newCoords.y;
		coordsInMemory[2] = newCoords.z;
	}


	// changes the FoV with the specified amount
	void changeFoV(float amount)
	{
		if (nullptr == _cameraStructAddress)
		{
			return;
		}
		float* fovAddress = reinterpret_cast<float*>(_fovAddress);
		*fovAddress += amount;
	}


	void resetFOV()
	{
		if (nullptr == _cameraStructAddress)
		{
			return;
		}
		float* fovAddress = reinterpret_cast<float*>(_fovAddress);
		*fovAddress = DEFAULT_FOV_IN_DEGREES;	// original fov might not be initialized
	}


	// should restore the camera values in the camera structures to the cached values. This assures the free camera is always enabled at the original camera location.
	void restoreOriginalCameraValues()
	{
		if (nullptr == _cameraStructAddress || nullptr == _fovAddress)
		{
			return;
		}
		float* matrixInMemory = reinterpret_cast<float*>(_cameraStructAddress + CAMERA_COORDS_IN_STRUCT_OFFSET);
		memcpy(matrixInMemory, _originalMatrixData, 16 * sizeof(float));
		float *fovInMemory = reinterpret_cast<float*>(_fovAddress);
		*fovInMemory = _originalFoV;
	}


	void cacheOriginalCameraValues()
	{
		if (nullptr == _cameraStructAddress || nullptr == _fovAddress)
		{
			return;
		}
		float* matrixInMemory = reinterpret_cast<float*>(_cameraStructAddress + CAMERA_COORDS_IN_STRUCT_OFFSET);
		memcpy(_originalMatrixData, matrixInMemory, 16 * sizeof(float));
		float* fovInMemory = reinterpret_cast<float*>(_fovAddress);
		_originalFoV = *fovInMemory;
	}
}