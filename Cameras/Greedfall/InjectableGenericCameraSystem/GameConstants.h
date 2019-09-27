//////////////////////////	//////////////////////////////////////////////////////////////////////////////
// Part of Injectable Generic Camera System
// Copyright(c) 2019, Frans Bouma
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
#pragma once

namespace IGCS::GameSpecific
{
	// Mandatory constants to define for a game
	#define GAME_NAME									"GreedFall 1.0+"
	#define CAMERA_VERSION								"1.0.2"
	#define CAMERA_CREDITS								"Jim2Point0. Additional coding by Otis_Inf."
	#define GAME_WINDOW_TITLE							"GreedFall"
	#define INITIAL_PITCH_RADIANS						(0.5f * DirectX::XM_PI)
	#define INITIAL_YAW_RADIANS							0.0f
	#define INITIAL_ROLL_RADIANS						0.0f
	#define CONTROLLER_Y_INVERT							false
	#define FASTER_MULTIPLIER							5.0f
	#define SLOWER_MULTIPLIER							0.1f
	#define MOUSE_SPEED_CORRECTION						0.2f	// to correct for the mouse-deltas related to normal rotation.
	#define DEFAULT_MOVEMENT_SPEED						2.5f
	#define DEFAULT_ROTATION_SPEED						0.01f
	#define DEFAULT_FOV_SPEED							0.1f
	#define DEFAULT_UP_MOVEMENT_MULTIPLIER				0.7f
	// End Mandatory constants

	// AOB Keys for interceptor's AOB scanner
	#define CAMERA_ADDRESS_INTERCEPT_KEY				"AOB_CAMERA_ADDRESS_INTERCEPT"
	#define CAMERA_WRITE1_INTERCEPT_KEY					"AOB_CAMERA_WRITE1_INTERCEPT"
	#define CAMERA_WRITE2_INTERCEPT_KEY					"AOB_CAMERA_WRITE2_INTERCEPT"
	#define CAMERA_WRITE3_INTERCEPT_KEY					"AOB_CAMERA_WRITE32_INTERCEPT"
	#define TOD_WRITE_INTERCEPT_KEY						"AOB_TOD_WRITE_INTERCEPT"
	#define FOV_WRITE_INTERCEPT_KEY						"AOB_FOV_WRITE_INTERCEPT"
	#define GAMESPEED_READ_INTERCEPT_KEY				"AOB_GAMESPEED_READ_INTERCEPT"
	#define FOG_WRITE_INTERCEPT_KEY						"AOB_FOG_WRITE_INTERCEPT"
	
	// Indices in the structures read by interceptors 
	#define COORDS_IN_STRUCT_OFFSET						0xE0
	#define MATRIX_IN_STRUCT_OFFSET						0xB0
	#define FOV_IN_STRUCT_OFFSET						0x1F0
	#define GAMESPEED_IN_STRUCT_OFFSET					0x24
	#define TOD_IN_STRUCT_OFFSET						0x2C
	#define FOG1_IN_STRUCT_OFFSET						0x174
	#define FOG2_IN_STRUCT_OFFSET						0x178
	#define FOG3_IN_STRUCT_OFFSET						0x180
	#define FOG_BLEND_FACTOR_OFFSET						0x17C
	#define FOG_COLOR_OFFSET							0x160
}
