;////////////////////////////////////////////////////////////////////////////////////////////////////////
;// Part of Injectable Generic Camera System
;// Copyright(c) 2017, Frans Bouma
;// All rights reserved.
;// https://github.com/FransBouma/InjectableGenericCameraSystem
;//
;// Redistribution and use in source and binary forms, with or without
;// modification, are permitted provided that the following conditions are met :
;//
;//  * Redistributions of source code must retain the above copyright notice, this
;//	  list of conditions and the following disclaimer.
;//
;//  * Redistributions in binary form must reproduce the above copyright notice,
;//    this list of conditions and the following disclaimer in the documentation
;//    and / or other materials provided with the distribution.
;//
;// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;// DISCLAIMED.IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
;// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;// DAMAGES(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
;// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
;// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
;// OR TORT(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;////////////////////////////////////////////////////////////////////////////////////////////////////////
;---------------------------------------------------------------
; Game specific asm file to intercept execution flow to obtain addresses, prevent writes etc.
;---------------------------------------------------------------


;---------------------------------------------------------------
; Public definitions so the linker knows which names are present in this file
PUBLIC pmStructAddressInterceptor
PUBLIC activeCamAddressInterceptor
PUBLIC activeCamWrite1Interceptor
PUBLIC resolutionStructAddressInterceptor
PUBLIC todStructAddressInterceptor
PUBLIC playHudWidgetReadInterceptor
PUBLIC pmHudWidgetReadInterceptor
PUBLIC fovPlayWriteInterceptor
PUBLIC timestopStructInterceptor
PUBLIC weatherStructInterceptor

;---------------------------------------------------------------

;---------------------------------------------------------------
; Externs which are used and set by the system. Read / write these
; values in asm to communicate with the system
EXTERN g_cameraEnabled: byte
EXTERN g_wetness_StreetWetnessFactor: dword
EXTERN g_wetness_OverrideParameters: byte
EXTERN g_pmStructAddress: qword
EXTERN g_activeCamStructAddress: qword
EXTERN g_resolutionStructAddress: qword
EXTERN g_todStructAddress: qword
EXTERN g_playHudWidgetAddress: qword
EXTERN g_pmHudWidgetAddress: qword
EXTERN g_timestopStructAddress: qword
EXTERN g_weatherStructAddress: qword

;---------------------------------------------------------------

;---------------------------------------------------------------
; Own externs, defined in InterceptorHelper.cpp
EXTERN _pmStructAddressInterceptionContinue: qword
EXTERN _activeCamAddressInterceptionContinue: qword
EXTERN _activeCamWrite1InterceptionContinue: qword
EXTERN _resolutionStructAddressInterceptionContinue: qword
EXTERN _todStructAddressInterceptionContinue:qword
EXTERN _playHudWidgetReadInterceptionContinue:qword
EXTERN _pmHudWidgetReadInterceptionContinue:qword
EXTERN _fovPlayWriteInterceptionContinue:qword
EXTERN _timestopStructInterceptionContinue:qword
EXTERN _weatherStructInterceptionContinue:qword

.data

_moistureFactorOverrideValue REAL4 1.0f

.code

activeCamAddressInterceptor PROC
;Cyberpunk2077.exe+FED742 - 8B 41 C8              - mov eax,[rcx-38]
;Cyberpunk2077.exe+FED745 - 48 8B F2              - mov rsi,rdx
;Cyberpunk2077.exe+FED748 - 89 42 08              - mov [rdx+08],eax
;Cyberpunk2077.exe+FED74B - 0F10 41 D0            - movups xmm0,[rcx-30]
;Cyberpunk2077.exe+FED74F - 48 8B CB              - mov rcx,rbx
;Cyberpunk2077.exe+FED752 - 0F11 42 10            - movups [rdx+10],xmm0
;Cyberpunk2077.exe+FED756 - 48 8B 03              - mov rax,[rbx]
;Cyberpunk2077.exe+FED759 - FF 90 58020000        - call qword ptr [rax+00000258]		<< INTERCEPT HERE >> Call get fov . RCX contains pointer to active camera.
;Cyberpunk2077.exe+FED75F - F3 0F11 46 20         - movss [rsi+20],xmm0
;Cyberpunk2077.exe+FED764 - 48 8D 54 24 20        - lea rdx,[rsp+20]
;Cyberpunk2077.exe+FED769 - 48 8B 03              - mov rax,[rbx]						<< CONTINUE HERE
;Cyberpunk2077.exe+FED76C - 48 8B CB              - mov rcx,rbx
;Cyberpunk2077.exe+FED76F - FF 90 60020000        - call qword ptr [rax+00000260]
;Cyberpunk2077.exe+FED775 - 4C 8D 46 40           - lea r8,[rsi+40]
;Cyberpunk2077.exe+FED779 - 48 8B CB              - mov rcx,rbx
;Cyberpunk2077.exe+FED77C - 48 8D 56 3C           - lea rdx,[rsi+3C]
;Cyberpunk2077.exe+FED780 - 0F10 00               - movups xmm0,[rax]
;Cyberpunk2077.exe+FED783 - 0F11 46 24            - movups [rsi+24],xmm0
;Cyberpunk2077.exe+FED787 - F2 0F10 48 10         - movsd xmm1,[rax+10]
;Cyberpunk2077.exe+FED78C - F2 0F11 4E 34         - movsd [rsi+34],xmm1
;Cyberpunk2077.exe+FED791 - 48 8B 03              - mov rax,[rbx]
;Cyberpunk2077.exe+FED794 - FF 90 70020000        - call qword ptr [rax+00000270]
;Cyberpunk2077.exe+FED79A - 48 8B 03              - mov rax,[rbx]
;Cyberpunk2077.exe+FED79D - 4C 8D 46 50           - lea r8,[rsi+50]
;Cyberpunk2077.exe+FED7A1 - 48 8D 56 4C           - lea rdx,[rsi+4C]
	mov [g_activeCamStructAddress], rcx
	call qword ptr [rax+00000258h]
	movss dword ptr [rsi+20h],xmm0
	lea rdx,[rsp+20h]
exit:
	jmp qword ptr [_activeCamAddressInterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
activeCamAddressInterceptor ENDP


activeCamWrite1Interceptor PROC
; Writes to many destinations but blocking all these writes doesn't have side effects. However blocking all writes regardless whether it's targeting our
; struct will also block writes when the pm isn't enabled. So we'll check if the destination address is our freecam struct. 
;Cyberpunk2077.exe+10B129A - E8 219013FF           - call Cyberpunk2077.exe+1EA2C0
;Cyberpunk2077.exe+10B129F - 0F10 40 10            - movups xmm0,[rax+10]
;Cyberpunk2077.exe+10B12A3 - 8B 08                 - mov ecx,[rax]
;Cyberpunk2077.exe+10B12A5 - 89 4C 24 20           - mov [rsp+20],ecx
;Cyberpunk2077.exe+10B12A9 - 8B 48 04              - mov ecx,[rax+04]
;Cyberpunk2077.exe+10B12AC - 0F29 44 24 30         - movaps [rsp+30],xmm0
;Cyberpunk2077.exe+10B12B1 - 89 4C 24 24           - mov [rsp+24],ecx
;Cyberpunk2077.exe+10B12B5 - 8B 48 08              - mov ecx,[rax+08]
;Cyberpunk2077.exe+10B12B8 - F2 0F10 44 24 20      - movsd xmm0,[rsp+20]
;Cyberpunk2077.exe+10B12BE - F2 0F11 83 E0000000   - movsd [rbx+000000E0],xmm0				<< INTERCEPT HERE << Write coords in packed int32 format
;Cyberpunk2077.exe+10B12C6 - 0F28 44 24 30         - movaps xmm0,[rsp+30]
;Cyberpunk2077.exe+10B12CB - 89 8B E8000000        - mov [rbx+000000E8],ecx
;Cyberpunk2077.exe+10B12D1 - 0F11 83 F0000000      - movups [rbx+000000F0],xmm0				<< Write quaternion
;Cyberpunk2077.exe+10B12D8 - 80 BB B1000000 00     - cmp byte ptr [rbx+000000B1],00 { 0 }	<< CONTINUE HERE
;Cyberpunk2077.exe+10B12DF - 75 0E                 - jne Cyberpunk2077.exe+10B12EF
;Cyberpunk2077.exe+10B12E1 - 80 BB B0000000 00     - cmp byte ptr [rbx+000000B0],00 { 0 }
;Cyberpunk2077.exe+10B12E8 - 75 05                 - jne Cyberpunk2077.exe+10B12EF
;Cyberpunk2077.exe+10B12EA - 40 32 FF              - xor dil,dil
;Cyberpunk2077.exe+10B12ED - EB 03                 - jmp Cyberpunk2077.exe+10B12F2
;Cyberpunk2077.exe+10B12EF - 40 B7 01              - mov dil,01 { 1 }
;Cyberpunk2077.exe+10B12F2 - 44 3B BB E0000000     - cmp r15d,[rbx+000000E0]
;Cyberpunk2077.exe+10B12F9 - 4C 8B BC 24 A0000000  - mov r15,[rsp+000000A0]
;Cyberpunk2077.exe+10B1301 - 75 2F                 - jne Cyberpunk2077.exe+10B1332
	cmp rbx, [g_activeCamStructAddress]
	jne originalCode
	cmp byte ptr [g_cameraEnabled], 1
	jne originalCode
noWrites:
	movaps xmm0, xmmword ptr  [rsp+30h]
	jmp exit
originalCode:
	movsd qword ptr [rbx+000000E0h],xmm0	
	movaps xmm0, xmmword ptr  [rsp+30h]
	mov [rbx+000000E8h],ecx
	movups xmmword ptr [rbx+000000F0h],xmm0
exit:
	jmp qword ptr [_activeCamWrite1InterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
activeCamWrite1Interceptor ENDP

pmStructAddressInterceptor PROC
;Cyberpunk2077.exe+25B6719 - 74 2B                 - je Cyberpunk2077.exe+25B6746
;Cyberpunk2077.exe+25B671B - 41 8B C7              - mov eax,r15d
;Cyberpunk2077.exe+25B671E - F0 0FC1 01            - lock xadd [rcx],eax
;Cyberpunk2077.exe+25B6722 - 83 F8 01              - cmp eax,01 { 1 }
;Cyberpunk2077.exe+25B6725 - 75 1F                 - jne Cyberpunk2077.exe+25B6746
;Cyberpunk2077.exe+25B6727 - 48 8D 4D F0           - lea rcx,[rbp-10]
;Cyberpunk2077.exe+25B672B - E8 60B1C0FD           - call Cyberpunk2077.exe+1C1890
;Cyberpunk2077.exe+25B6730 - 48 8D 4D F0           - lea rcx,[rbp-10]
;Cyberpunk2077.exe+25B6734 - E8 B777C6FD           - call Cyberpunk2077.exe+21DEF0
;Cyberpunk2077.exe+25B6739 - 84 C0                 - test al,al
;Cyberpunk2077.exe+25B673B - 74 09                 - je Cyberpunk2077.exe+25B6746
;Cyberpunk2077.exe+25B673D - 48 8D 4D F0           - lea rcx,[rbp-10]
;Cyberpunk2077.exe+25B6741 - E8 4A77C6FD           - call Cyberpunk2077.exe+21DE90
;Cyberpunk2077.exe+25B6746 - 49 8B 4E 40           - mov rcx,[r14+40]				<< INTERCEPT HERE				>> R14 contains the photomode struct we need.
;Cyberpunk2077.exe+25B674A - 48 8D 95 90000000     - lea rdx,[rbp+00000090]
;Cyberpunk2077.exe+25B6751 - 41 88 9E FB020000     - mov [r14+000002FB],bl
;Cyberpunk2077.exe+25B6758 - E8 6377FFFF           - call Cyberpunk2077.exe+25ADEC0	<< CONTINUE HERE
;Cyberpunk2077.exe+25B675D - 48 8B 55 D0           - mov rdx,[rbp-30]
;Cyberpunk2077.exe+25B6761 - 4C 8D 05 B8410702     - lea r8,[Cyberpunk2077.exe+462A920] { (-1285889246) }
;Cyberpunk2077.exe+25B6768 - 48 8B 8D 90000000     - mov rcx,[rbp+00000090]
;Cyberpunk2077.exe+25B676F - 48 83 C2 48           - add rdx,48 { 72 }
;Cyberpunk2077.exe+25B6773 - E8 E84B40FF           - call Cyberpunk2077.exe+19BB360
;Cyberpunk2077.exe+25B6778 - 84 C0                 - test al,al
;Cyberpunk2077.exe+25B677A - 75 35                 - jne Cyberpunk2077.exe+25B67B1
;Cyberpunk2077.exe+25B677C - 48 8B 7D D0           - mov rdi,[rbp-30]
;Cyberpunk2077.exe+25B6780 - 48 8D 15 1939E300     - lea rdx,[Cyberpunk2077.exe+33EA0A0] { ("GameplayRestriction.NoCameraControl") }
;Cyberpunk2077.exe+25B6787 - 48 8B B5 90000000     - mov rsi,[rbp+00000090]
;Cyberpunk2077.exe+25B678E - 48 8D 8D 28020000     - lea rcx,[rbp+00000228]
;Cyberpunk2077.exe+25B6795 - E8 66235100           - call Cyberpunk2077.exe+2AC8B00
;Cyberpunk2077.exe+25B679A - 4C 8B C0              - mov r8,rax
;Cyberpunk2077.exe+25B679D - 48 8D 57 48           - lea rdx,[rdi+48]
	mov [g_pmStructAddress], r14
	mov rcx,[r14+40h]		
	lea rdx,[rbp+00000090h]
	mov [r14+000002FBh],bl
exit:
	jmp qword ptr [_pmStructAddressInterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
pmStructAddressInterceptor ENDP


resolutionStructAddressInterceptor PROC
;Cyberpunk2077.exe+26C3F4B - 80 BB BF000000 00     - cmp byte ptr [rbx+000000BF],00 { 0 }
;Cyberpunk2077.exe+26C3F52 - 0F85 92000000         - jne Cyberpunk2077.exe+26C3FEA
;Cyberpunk2077.exe+26C3F58 - 0FB6 83 82000000      - movzx eax,byte ptr [rbx+00000082]
;Cyberpunk2077.exe+26C3F5F - 38 43 3C              - cmp [rbx+3C],al
;Cyberpunk2077.exe+26C3F62 - 0F85 82000000         - jne Cyberpunk2077.exe+26C3FEA
;Cyberpunk2077.exe+26C3F68 - 8B 43 74              - mov eax,[rbx+74]					>> rbx contains resolution struct pointer. 0x74 is WIDTH
;Cyberpunk2077.exe+26C3F6B - 39 43 18              - cmp [rbx+18],eax
;Cyberpunk2077.exe+26C3F6E - 75 7A                 - jne Cyberpunk2077.exe+26C3FEA
;Cyberpunk2077.exe+26C3F70 - 8B 43 78              - mov eax,[rbx+78]					>> HEIGHT 
;Cyberpunk2077.exe+26C3F73 - 39 43 1C              - cmp [rbx+1C],eax
;Cyberpunk2077.exe+26C3F76 - 75 72                 - jne Cyberpunk2077.exe+26C3FEA
;Cyberpunk2077.exe+26C3F78 - 0FB6 83 81000000      - movzx eax,byte ptr [rbx+00000081]
;Cyberpunk2077.exe+26C3F7F - 38 43 28              - cmp [rbx+28],al
;Cyberpunk2077.exe+26C3F82 - 75 66                 - jne Cyberpunk2077.exe+26C3FEA
;Cyberpunk2077.exe+26C3F84 - 3A 8B 80000000        - cmp cl,[rbx+00000080]
;Cyberpunk2077.exe+26C3F8A - 75 5E                 - jne Cyberpunk2077.exe+26C3FEA
;Cyberpunk2077.exe+26C3F8C - 8B 43 7C              - mov eax,[rbx+7C]
;Cyberpunk2077.exe+26C3F8F - 39 43 68              - cmp [rbx+68],eax
;Cyberpunk2077.exe+26C3F92 - 75 56                 - jne Cyberpunk2077.exe+26C3FEA
;Cyberpunk2077.exe+26C3F94 - 0FB6 43 3E            - movzx eax,byte ptr [rbx+3E]
;Cyberpunk2077.exe+26C3F98 - 38 83 83000000        - cmp [rbx+00000083],al
;Cyberpunk2077.exe+26C3F9E - 75 4A                 - jne Cyberpunk2077.exe+26C3FEA
;Cyberpunk2077.exe+26C3FA0 - 0FB6 83 9C000000      - movzx eax,byte ptr [rbx+0000009C]
;Cyberpunk2077.exe+26C3FA7 - 38 83 C0000000        - cmp [rbx+000000C0],al
;Cyberpunk2077.exe+26C3FAD - 75 3B                 - jne Cyberpunk2077.exe+26C3FEA
;// however this isn't hookable due to all the jne's. So we hook a bit higher in the function:
;Cyberpunk2077.exe+26C3E5D - 8B 81 84000000        - mov eax,[rcx+00000084]			<< INTERCEPT HERE
;Cyberpunk2077.exe+26C3E63 - 89 41 44              - mov [rcx+44],eax
;Cyberpunk2077.exe+26C3E66 - 8B 81 88000000        - mov eax,[rcx+00000088]
;Cyberpunk2077.exe+26C3E6C - 89 41 40              - mov [rcx+40],eax
;Cyberpunk2077.exe+26C3E6F - 8B 81 8C000000        - mov eax,[rcx+0000008C]			<< CONTINUE HERE
;Cyberpunk2077.exe+26C3E75 - 89 41 48              - mov [rcx+48],eax
;Cyberpunk2077.exe+26C3E78 - 8B 81 90000000        - mov eax,[rcx+00000090]
;Cyberpunk2077.exe+26C3E7E - 89 41 4C              - mov [rcx+4C],eax
;Cyberpunk2077.exe+26C3E81 - 8B 81 98000000        - mov eax,[rcx+00000098]
;Cyberpunk2077.exe+26C3E87 - 89 41 54              - mov [rcx+54],eax
;Cyberpunk2077.exe+26C3E8A - 8B 81 94000000        - mov eax,[rcx+00000094]
;Cyberpunk2077.exe+26C3E90 - 89 41 50              - mov [rcx+50],eax
;Cyberpunk2077.exe+26C3E93 - 0FB6 49 20            - movzx ecx,byte ptr [rcx+20]
;Cyberpunk2077.exe+26C3E97 - 80 F9 03              - cmp cl,03 { 3 }
;Cyberpunk2077.exe+26C3E9A - 0F85 AB000000         - jne Cyberpunk2077.exe+26C3F4B
;Cyberpunk2077.exe+26C3EA0 - 8B 43 74              - mov eax,[rbx+74]
;Cyberpunk2077.exe+26C3EA3 - 39 43 18              - cmp [rbx+18],eax
;Cyberpunk2077.exe+26C3EA6 - 75 73                 - jne Cyberpunk2077.exe+26C3F1B
;Cyberpunk2077.exe+26C3EA8 - 8B 43 78              - mov eax,[rbx+78]
;Cyberpunk2077.exe+26C3EAB - 39 43 1C              - cmp [rbx+1C],eax
;Cyberpunk2077.exe+26C3EAE - 75 6B                 - jne Cyberpunk2077.exe+26C3F1B
	mov [g_resolutionStructAddress], rbx
	mov eax,[rcx+00000084h]
	mov [rcx+44h],eax
	mov eax,[rcx+00000088h]
	mov [rcx+40h],eax
exit:
	jmp qword ptr [_resolutionStructAddressInterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
resolutionStructAddressInterceptor ENDP

todStructAddressInterceptor PROC
;Cyberpunk2077.exe+17461D0 - 40 53                 - push rbx
;Cyberpunk2077.exe+17461D2 - 48 83 EC 20           - sub rsp,20 { 32 }
;Cyberpunk2077.exe+17461D6 - 48 8B 89 E8000000     - mov rcx,[rcx+000000E8]
;Cyberpunk2077.exe+17461DD - 48 8B DA              - mov rbx,rdx						<< INTERCEPT HERE
;Cyberpunk2077.exe+17461E0 - 48 8B 01              - mov rax,[rcx]
;Cyberpunk2077.exe+17461E3 - FF 90 F8000000        - call qword ptr [rax+000000F8]		>> Call tod read, we need the rcx
;Cyberpunk2077.exe+17461E9 - 48 8B C3              - mov rax,rbx
;Cyberpunk2077.exe+17461EC - 48 83 C4 20           - add rsp,20 { 32 }					<< CONTINUE HERE
;Cyberpunk2077.exe+17461F0 - 5B                    - pop rbx
;Cyberpunk2077.exe+17461F1 - C3                    - ret 
	mov rbx,rdx					
	mov rax,[rcx]
	mov [g_todStructAddress], rcx
	call qword ptr [rax+000000F8h]
	mov rax,rbx
exit:
	jmp qword ptr [_todStructAddressInterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
todStructAddressInterceptor ENDP

playHudWidgetReadInterceptor PROC
;Cyberpunk2077.exe+867B81 - 48 89 4C 24 20        - mov [rsp+20],rcx
;Cyberpunk2077.exe+867B86 - 48 89 44 24 28        - mov [rsp+28],rax
;Cyberpunk2077.exe+867B8B - 48 85 C9              - test rcx,rcx
;Cyberpunk2077.exe+867B8E - 74 54                 - je Cyberpunk2077.exe+867BE4
;Cyberpunk2077.exe+867B90 - 0FB6 81 B0000000      - movzx eax,byte ptr [rcx+000000B0]	
;Cyberpunk2077.exe+867B97 - 88 81 B1000000        - mov [rcx+000000B1],al				<< INTERCEPT HERE
;Cyberpunk2077.exe+867B9D - 48 89 BC 24 98000000  - mov [rsp+00000098],rdi
;Cyberpunk2077.exe+867BA5 - 48 8B 7C 24 20        - mov rdi,[rsp+20]
;Cyberpunk2077.exe+867BAA - 48 83 7F 40 00        - cmp qword ptr [rdi+40],00			<< CONTINUE HERE << PLAY Bucket read.
;Cyberpunk2077.exe+867BAF - 74 2B                 - je Cyberpunk2077.exe+867BDC
;Cyberpunk2077.exe+867BB1 - 48 8B D6              - mov rdx,rsi
;Cyberpunk2077.exe+867BB4 - 48 8D 4C 24 40        - lea rcx,[rsp+40]
;Cyberpunk2077.exe+867BB9 - E8 52392802           - call Cyberpunk2077.exe+2AEB510
;Cyberpunk2077.exe+867BBE - 48 8B 4F 40           - mov rcx,[rdi+40]
;Cyberpunk2077.exe+867BC2 - 48 8D 54 24 40        - lea rdx,[rsp+40]
;Cyberpunk2077.exe+867BC7 - 45 33 C9              - xor r9d,r9d
;Cyberpunk2077.exe+867BCA - 45 33 C0              - xor r8d,r8d
;Cyberpunk2077.exe+867BCD - E8 6E2A1000           - call Cyberpunk2077.exe+96A640
;Cyberpunk2077.exe+867BD2 - 48 8D 4C 24 40        - lea rcx,[rsp+40]
;Cyberpunk2077.exe+867BD7 - E8 D43A2802           - call Cyberpunk2077.exe+2AEB6B0
;Cyberpunk2077.exe+867BDC - 48 8B BC 24 98000000  - mov rdi,[rsp+00000098]
;Cyberpunk2077.exe+867BE4 - 48 8B 4C 24 28        - mov rcx,[rsp+28]
;Cyberpunk2077.exe+867BE9 - 48 85 C9              - test rcx,rcx
;Cyberpunk2077.exe+867BEC - 74 30                 - je Cyberpunk2077.exe+867C1E
	mov [rcx+000000B1h],al	
	mov [rsp+00000098h],rdi
	mov rdi,[rsp+20h]
	push rbx
	mov rbx, [rdi+40h]
	mov [g_playHudWidgetAddress], rbx
	pop rbx
exit:
	jmp qword ptr [_playHudWidgetReadInterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
playHudWidgetReadInterceptor ENDP

pmHudWidgetReadInterceptor PROC
;Cyberpunk2077.exe+8BA900 - 48 89 5C 24 10        - mov [rsp+10],rbx
;Cyberpunk2077.exe+8BA905 - 57                    - push rdi
;Cyberpunk2077.exe+8BA906 - 48 83 EC 20           - sub rsp,20 { 32 }
;Cyberpunk2077.exe+8BA90A - 80 B9 B0000000 00     - cmp byte ptr [rcx+000000B0],00
;Cyberpunk2077.exe+8BA911 - 48 8B F9              - mov rdi,rcx
;Cyberpunk2077.exe+8BA914 - 74 0A                 - je Cyberpunk2077.exe+8BA920				<< INTERCEPT HERE
;Cyberpunk2077.exe+8BA916 - 80 7A 40 00           - cmp byte ptr [rdx+40],00
;Cyberpunk2077.exe+8BA91A - 74 04                 - je Cyberpunk2077.exe+8BA920
;Cyberpunk2077.exe+8BA91C - B3 01                 - mov bl,01 { 1 }
;Cyberpunk2077.exe+8BA91E - EB 02                 - jmp Cyberpunk2077.exe+8BA922
;Cyberpunk2077.exe+8BA920 - 32 DB                 - xor bl,bl
;Cyberpunk2077.exe+8BA922 - 48 8B 49 40           - mov rcx,[rcx+40]						<< PM Buchet read.
;Cyberpunk2077.exe+8BA926 - 0FB6 D3               - movzx edx,bl							<< CONTINUE HERE
;Cyberpunk2077.exe+8BA929 - E8 D21C0B00           - call Cyberpunk2077.exe+96C600
;Cyberpunk2077.exe+8BA92E - 84 DB                 - test bl,bl
;Cyberpunk2077.exe+8BA930 - 75 45                 - jne Cyberpunk2077.exe+8BA977
;Cyberpunk2077.exe+8BA932 - 48 8B 4F 40           - mov rcx,[rdi+40]
;Cyberpunk2077.exe+8BA936 - 48 8D 54 24 40        - lea rdx,[rsp+40]
;Cyberpunk2077.exe+8BA93B - 48 8B 01              - mov rax,[rcx]
;Cyberpunk2077.exe+8BA93E - FF 90 28020000        - call qword ptr [rax+00000228]
;Cyberpunk2077.exe+8BA944 - 48 8B 4F 40           - mov rcx,[rdi+40]
;Cyberpunk2077.exe+8BA948 - 48 8D 54 24 30        - lea rdx,[rsp+30]
;Cyberpunk2077.exe+8BA94D - F3 0F10 10            - movss xmm2,[rax]
;Cyberpunk2077.exe+8BA951 - F3 0F10 48 04         - movss xmm1,[rax+04]
;Cyberpunk2077.exe+8BA956 - F3 0F59 15 2A356702   - mulss xmm2,[Cyberpunk2077.exe+2F2DE88]
;Cyberpunk2077.exe+8BA95E - F3 0F59 0D 22356702   - mulss xmm1,[Cyberpunk2077.exe+2F2DE88]
	je resetBl	
	cmp byte ptr [rdx+40h],00
	je resetBl
	mov bl,01h
	jmp readPmWidgetBucket
resetBl:
	xor bl,bl
readPmWidgetBucket:
	mov rcx,[rcx+40h]
	mov [g_pmHudWidgetAddress], rcx
exit:
	jmp qword ptr [_pmHudWidgetReadInterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
pmHudWidgetReadInterceptor ENDP


fovPlayWriteInterceptor PROC
;Cyberpunk2077.exe+16D4D32 - F3 0F5C C8            - subss xmm1,xmm0
;Cyberpunk2077.exe+16D4D36 - F3 0F59 C8            - mulss xmm1,xmm0
;Cyberpunk2077.exe+16D4D3A - F3 0F5C D9            - subss xmm3,xmm1
;Cyberpunk2077.exe+16D4D3E - F3 0F59 CC            - mulss xmm1,xmm4
;Cyberpunk2077.exe+16D4D42 - F3 0F59 9F 68020000   - mulss xmm3,[rdi+00000268]
;Cyberpunk2077.exe+16D4D4A - F3 0F58 D9            - addss xmm3,xmm1
;Cyberpunk2077.exe+16D4D4E - EB 03                 - jmp Cyberpunk2077.exe+16D4D53
;Cyberpunk2077.exe+16D4D50 - 0F28 DC               - movaps xmm3,xmm4							
;Cyberpunk2077.exe+16D4D53 - F3 0F11 9F 5C020000   - movss [rdi+0000025C],xmm3					<< INTERCEPT HERE << WRITE Gameplay fov.
;Cyberpunk2077.exe+16D4D5B - 48 8B 8F B0010000     - mov rcx,[rdi+000001B0]
;Cyberpunk2077.exe+16D4D62 - 0F2E 59 40            - ucomiss xmm3,[rcx+40]						<< CONTINUE HERE
;Cyberpunk2077.exe+16D4D66 - 74 10                 - je Cyberpunk2077.exe+16D4D78
;Cyberpunk2077.exe+16D4D68 - 8B 87 5C020000        - mov eax,[rdi+0000025C]
;Cyberpunk2077.exe+16D4D6E - 89 41 40              - mov [rcx+40],eax
;Cyberpunk2077.exe+16D4D71 - C6 87 55020000 01     - mov byte ptr [rdi+00000255],01 { 1 }
;Cyberpunk2077.exe+16D4D78 - 0F28 CF               - movaps xmm1,xmm7
;Cyberpunk2077.exe+16D4D7B - 48 8B CE              - mov rcx,rsi
;Cyberpunk2077.exe+16D4D7E - E8 6DA3FFFF           - call Cyberpunk2077.exe+16CF0F0
;Cyberpunk2077.exe+16D4D83 - 0F28 05 C6F0B401      - movaps xmm0,[Cyberpunk2077.exe+3223E50] { (999,00) }
;Cyberpunk2077.exe+16D4D8A - 48 8D 54 24 30        - lea rdx,[rsp+30]
;Cyberpunk2077.exe+16D4D8F - 48 8B CE              - mov rcx,rsi
;Cyberpunk2077.exe+16D4D92 - 0F11 44 24 30         - movups [rsp+30],xmm0
;Cyberpunk2077.exe+16D4D97 - E8 C4AAFFFF           - call Cyberpunk2077.exe+16CF860
	cmp byte ptr [g_cameraEnabled], 1
	je exit
	movss dword ptr [rdi+0000025Ch],xmm3
exit:
	mov rcx,[rdi+000001B0h]
	jmp qword ptr [_fovPlayWriteInterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
fovPlayWriteInterceptor ENDP


timestopStructInterceptor PROC
;Cyberpunk2077.exe+AB73E0 - 44 8B 49 1C           - mov r9d,[rcx+1C]					 << INTERCEPT HERE << READ Timestop. 1=>paused, 0=>run
;Cyberpunk2077.exe+AB73E4 - 48 85 D2              - test rdx,rdx
;Cyberpunk2077.exe+AB73E7 - 75 07                 - jne Cyberpunk2077.exe+AB73F0
;Cyberpunk2077.exe+AB73E9 - 45 85 C9              - test r9d,r9d
;Cyberpunk2077.exe+AB73EC - 0F95 C0               - setne al
;Cyberpunk2077.exe+AB73EF - C3                    - ret 
;Cyberpunk2077.exe+AB73F0 - 45 33 C0              - xor r8d,r8d							<< CONTINUE HERE 
;Cyberpunk2077.exe+AB73F3 - 45 85 C9              - test r9d,r9d
;Cyberpunk2077.exe+AB73F6 - 74 1E                 - je Cyberpunk2077.exe+AB7416
;Cyberpunk2077.exe+AB73F8 - 4C 8B 51 10           - mov r10,[rcx+10]
;Cyberpunk2077.exe+AB73FC - 0F1F 40 00            - nop dword ptr [rax+00]
;Cyberpunk2077.exe+AB7400 - 41 8B C0              - mov eax,r8d
;Cyberpunk2077.exe+AB7403 - 48 6B C8 70           - imul rcx,rax,70
;Cyberpunk2077.exe+AB7407 - 4A 39 54 11 08        - cmp [rcx+r10+08],rdx
;Cyberpunk2077.exe+AB740C - 74 0B                 - je Cyberpunk2077.exe+AB7419
;Cyberpunk2077.exe+AB740E - 41 FF C0              - inc r8d
;Cyberpunk2077.exe+AB7411 - 45 3B C1              - cmp r8d,r9d
;Cyberpunk2077.exe+AB7414 - 72 EA                 - jb Cyberpunk2077.exe+AB7400
;Cyberpunk2077.exe+AB7416 - 32 C0                 - xor al,al
;Cyberpunk2077.exe+AB7418 - C3                    - ret 
;Cyberpunk2077.exe+AB7419 - B0 01                 - mov al,01 { 1 }
;Cyberpunk2077.exe+AB741B - C3                    - ret 
	mov [g_timestopStructAddress], rcx
	mov r9d,[rcx+1Ch]			
	test rdx,rdx
	jne exit
	test r9d,r9d
	setne al
	ret				; will ret as normal.
exit:
	jmp qword ptr [_timestopStructInterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
timestopStructInterceptor ENDP

weatherStructInterceptor PROC
;Cyberpunk2077.exe+111A020 - 8B 85 2C0A0000        - mov eax,[rbp+00000A2C]
;Cyberpunk2077.exe+111A026 - 89 86 E4000000        - mov [rsi+000000E4],eax
;Cyberpunk2077.exe+111A02C - 8B 85 300A0000        - mov eax,[rbp+00000A30]
;Cyberpunk2077.exe+111A032 - 89 86 E8000000        - mov [rsi+000000E8],eax
;Cyberpunk2077.exe+111A038 - F3 0F10 95 380A0000   - movss xmm2,[rbp+00000A38]
;Cyberpunk2077.exe+111A040 - F3 0F11 96 F0000000   - movss [rsi+000000F0],xmm2		<< INTERCEPT HERE << Write moisture
;Cyberpunk2077.exe+111A048 - F3 0F5C C2            - subss xmm0,xmm2
;Cyberpunk2077.exe+111A04C - F3 0F10 8D 3C0A0000   - movss xmm1,[rbp+00000A3C]
;Cyberpunk2077.exe+111A054 - F3 0F11 8E F4000000   - movss [rsi+000000F4],xmm1
;Cyberpunk2077.exe+111A05C - 8B 85 400A0000        - mov eax,[rbp+00000A40]
;Cyberpunk2077.exe+111A062 - 89 86 F8000000        - mov [rsi+000000F8],eax			<< Write puddle strength
;Cyberpunk2077.exe+111A068 - F3 0F59 86 D0000000   - mulss xmm0,[rsi+000000D0]		<< CONTINUE HERE
;Cyberpunk2077.exe+111A070 - F3 0F59 CA            - mulss xmm1,xmm2
;Cyberpunk2077.exe+111A074 - F3 0F58 C1            - addss xmm0,xmm1
;Cyberpunk2077.exe+111A078 - F3 0F11 85 440A0000   - movss [rbp+00000A44],xmm0
;Cyberpunk2077.exe+111A080 - F3 0F10 8E F0000000   - movss xmm1,[rsi+000000F0]
;Cyberpunk2077.exe+111A088 - F3 0F5C D9            - subss xmm3,xmm1
	mov [g_weatherStructAddress], rsi
	cmp byte ptr [g_wetness_OverrideParameters], 1
	jne originalCode
	; write 1.0 to moisture. Use eax for that, we're going to overwrite it later anyway. Keep the value in xmm2
	; as otherwise the wetness on the streets isn't going to show.
	mov eax, dword ptr[_moistureFactorOverrideValue]
	mov [rsi+000000F0h], eax
	subss xmm0,xmm2
	movss xmm1, dword ptr [rbp+00000A3Ch]
	movss dword ptr [rsi+000000F4h],xmm1	; 0xF4 offset is not important
	mov eax,[rbp+00000A40h]	
	; no write to 0xF8
	; write streetwetnessfactor to d0 so it stays at that value.
	mov eax, [g_wetness_StreetWetnessFactor]
	mov [rsi+0D0h], eax
	jmp exit
originalCode:
	movss dword ptr [rsi+000000F0h],xmm2	
	subss xmm0,xmm2
	movss xmm1, dword ptr [rbp+00000A3Ch]
	movss dword ptr [rsi+000000F4h],xmm1
	mov eax,[rbp+00000A40h]
	mov [rsi+000000F8h],eax
exit:
	jmp qword ptr [_weatherStructInterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
weatherStructInterceptor ENDP

END