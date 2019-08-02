;////////////////////////////////////////////////////////////////////////////////////////////////////////
;// Part of Injectable Generic Camera System
;// Copyright(c) 2019, Frans Bouma
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
PUBLIC cameraStructInterceptor
PUBLIC cameraWrite1Interceptor
PUBLIC cameraWrite2Interceptor
PUBLIC cameraWrite3Interceptor
PUBLIC timestopReadInterceptor
PUBLIC resolutionScaleReadInterceptor
PUBLIC displayTypeInterceptor
PUBLIC dofSelectorWriteInterceptor

;---------------------------------------------------------------

;---------------------------------------------------------------
; Externs which are used and set by the system. Read / write these
; values in asm to communicate with the system
EXTERN g_cameraEnabled: byte
EXTERN g_cameraStructAddress: qword
EXTERN g_resolutionScaleAddress: qword
EXTERN g_timestopStructAddress: qword
EXTERN g_displayTypeStructAddress: qword
EXTERN g_dofStructAddress: qword

;---------------------------------------------------------------

;---------------------------------------------------------------
; Own externs, defined in InterceptorHelper.cpp
EXTERN _cameraStructInterceptionContinue: qword
EXTERN _cameraWrite1InterceptionContinue: qword
EXTERN _cameraWrite2InterceptionContinue: qword
EXTERN _cameraWrite3InterceptionContinue: qword
EXTERN _timestopReadInterceptionContinue: qword
EXTERN _resolutionScaleReadInterceptionContinue: qword
EXTERN _displayTypeInterceptionContinue: qword
EXTERN _dofSelectorWriteInterceptionContinue: qword

.data

.code

cameraStructInterceptor PROC
; camera address interceptor is also a the FoV write blocker.
;DevilMayCry5.exe+14AEB6DA - F3 0F10 85 B8000000   - movss xmm0,[rbp+000000B8]
;DevilMayCry5.exe+14AEB6E2 - 0F2F F0               - comiss xmm6,xmm0
;DevilMayCry5.exe+14AEB6E5 - 73 19                 - jae DevilMayCry5.exe+14AEB700
;DevilMayCry5.exe+14AEB6E7 - 0F2F 05 52CC99EF      - comiss xmm0,[DevilMayCry5.exe+4488340]
;DevilMayCry5.exe+14AEB6EE - 76 05                 - jna DevilMayCry5.exe+14AEB6F5
;DevilMayCry5.exe+14AEB6F0 - F3 0F11 46 38         - movss [rsi+38],xmm0					<< INTERCEPT HERE <<< WRITE FOV11
;DevilMayCry5.exe+14AEB6F5 - 48 8B 43 50           - mov rax,[rbx+50]
;DevilMayCry5.exe+14AEB6F9 - 48 83 78 18 00        - cmp qword ptr [rax+18],00 { 0 }
;DevilMayCry5.exe+14AEB6FE - 75 25                 - jne DevilMayCry5.exe+14AEB725			<<< CONTINUE HERE
;DevilMayCry5.exe+14AEB700 - F3 0F10 85 C0000000   - movss xmm0,[rbp+000000C0]
;DevilMayCry5.exe+14AEB708 - F3 0F11 46 30         - movss [rsi+30],xmm0
;DevilMayCry5.exe+14AEB70D - 48 8B 43 50           - mov rax,[rbx+50]
;DevilMayCry5.exe+14AEB711 - 48 83 78 18 00        - cmp qword ptr [rax+18],00 { 0 }
;DevilMayCry5.exe+14AEB716 - 75 0D                 - jne DevilMayCry5.exe+14AEB725
	mov [g_cameraStructAddress], rsi
	cmp byte ptr [g_cameraEnabled], 1
	je exit
originalCode:
	movss dword ptr [rsi+38h],xmm0
exit:
	mov rax,[rbx+50h]
	cmp qword ptr [rax+18h],00h
	jmp qword ptr [_cameraStructInterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
cameraStructInterceptor ENDP


cameraWrite1Interceptor PROC
; quaterion write 1
;DevilMayCry5.exe+179E554B - F3 0F11 77 4C         - movss [rdi+4C],xmm6
;DevilMayCry5.exe+179E5550 - 0F28 B4 24 80000000   - movaps xmm6,[rsp+00000080]
;DevilMayCry5.exe+179E5558 - EB 1B                 - jmp DevilMayCry5.exe+179E5575
;DevilMayCry5.exe+179E555A - 41 8B 06              - mov eax,[r14]						<< INTERCEPT HERE
;DevilMayCry5.exe+179E555D - 89 47 40              - mov [rdi+40],eax					<< qX
;DevilMayCry5.exe+179E5560 - 41 8B 46 04           - mov eax,[r14+04]
;DevilMayCry5.exe+179E5564 - 89 47 44              - mov [rdi+44],eax					<< qY
;DevilMayCry5.exe+179E5567 - 41 8B 46 08           - mov eax,[r14+08]
;DevilMayCry5.exe+179E556B - 89 47 48              - mov [rdi+48],eax					<< qZ
;DevilMayCry5.exe+179E556E - 41 8B 46 0C           - mov eax,[r14+0C]
;DevilMayCry5.exe+179E5572 - 89 47 4C              - mov [rdi+4C],eax					<< qW
;DevilMayCry5.exe+179E5575 - 80 BF D2000000 00     - cmp byte ptr [rdi+000000D2],00		<< CONTINUE HERE
;DevilMayCry5.exe+179E557C - C6 87 D1000000 01     - mov byte ptr [rdi+000000D1],01
;DevilMayCry5.exe+179E5583 - 75 08                 - jne DevilMayCry5.exe+179E558D
	cmp byte ptr [g_cameraEnabled], 1
	je exit
originalCode:
	mov eax,[r14]	
	mov [rdi+40h],eax
	mov eax,[r14+04h]
	mov [rdi+44h],eax
	mov eax,[r14+08h]
	mov [rdi+48h],eax
	mov eax,[r14+0Ch]
	mov [rdi+4Ch],eax
exit:
	jmp qword ptr [_cameraWrite1InterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
cameraWrite1Interceptor ENDP

cameraWrite2Interceptor PROC
; quaterion write 2
;DevilMayCry5.exe+179E3A21 - 48 8D 57 40           - lea rdx,[rdi+40]
;DevilMayCry5.exe+179E3A25 - 48 8D 4C 24 30        - lea rcx,[rsp+30]
;DevilMayCry5.exe+179E3A2A - E8 61A6A6EA           - call DevilMayCry5.exe+244E090
;DevilMayCry5.exe+179E3A2F - 8B 08                 - mov ecx,[rax]						<< INTERCEPT HERE
;DevilMayCry5.exe+179E3A31 - 89 4F 40              - mov [rdi+40],ecx					<< qX
;DevilMayCry5.exe+179E3A34 - 8B 48 04              - mov ecx,[rax+04]
;DevilMayCry5.exe+179E3A37 - 89 4F 44              - mov [rdi+44],ecx					<< qY
;DevilMayCry5.exe+179E3A3A - 8B 48 08              - mov ecx,[rax+08]
;DevilMayCry5.exe+179E3A3D - 89 4F 48              - mov [rdi+48],ecx					<< qZ
;DevilMayCry5.exe+179E3A40 - 8B 40 0C              - mov eax,[rax+0C]
;DevilMayCry5.exe+179E3A43 - 89 47 4C              - mov [rdi+4C],eax					<< qW
;DevilMayCry5.exe+179E3A46 - 80 BF D2000000 00     - cmp byte ptr [rdi+000000D2],00		<< CONTINUE HERE
;DevilMayCry5.exe+179E3A4D - C6 87 D1000000 01     - mov byte ptr [rdi+000000D1],01
;DevilMayCry5.exe+179E3A54 - 75 08                 - jne DevilMayCry5.exe+179E3A5E
;DevilMayCry5.exe+179E3A56 - 48 89 F9              - mov rcx,rdi
	cmp byte ptr [g_cameraEnabled], 1
	je exit
originalCode:
	mov ecx,[rax]	
	mov [rdi+40h],ecx
	mov ecx,[rax+04h]
	mov [rdi+44h],ecx
	mov ecx,[rax+08h]
	mov [rdi+48h],ecx
	mov eax,[rax+0Ch]
	mov [rdi+4Ch],eax
exit:
	jmp qword ptr [_cameraWrite2InterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
cameraWrite2Interceptor ENDP

cameraWrite3Interceptor PROC
; coords write 1
;DevilMayCry5.exe+179E5233 - F3 0F11 57 38         - movss [rdi+38],xmm2
;DevilMayCry5.exe+179E5238 - F3 0F11 47 34         - movss [rdi+34],xmm0
;DevilMayCry5.exe+179E523D - EB 14                 - jmp DevilMayCry5.exe+179E5253
;DevilMayCry5.exe+179E523F - 41 8B 06              - mov eax,[r14]						<< INTERCEPT HERE
;DevilMayCry5.exe+179E5242 - 89 47 30              - mov [rdi+30],eax					<< X
;DevilMayCry5.exe+179E5245 - 41 8B 46 04           - mov eax,[r14+04]
;DevilMayCry5.exe+179E5249 - 89 47 34              - mov [rdi+34],eax					<< Y
;DevilMayCry5.exe+179E524C - 41 8B 46 08           - mov eax,[r14+08]
;DevilMayCry5.exe+179E5250 - 89 47 38              - mov [rdi+38],eax					<< Z
;DevilMayCry5.exe+179E5253 - 80 BF D2000000 00     - cmp byte ptr [rdi+000000D2],00		<< CONTINUE HERE
;DevilMayCry5.exe+179E525A - C6 87 D1000000 01     - mov byte ptr [rdi+000000D1],01
;DevilMayCry5.exe+179E5261 - 75 08                 - jne DevilMayCry5.exe+179E526B
	cmp byte ptr [g_cameraEnabled], 1
	je exit
originalCode:
	mov eax,[r14]	
	mov [rdi+30h],eax
	mov eax,[r14+04h]
	mov [rdi+34h],eax
	mov eax,[r14+08h]
	mov [rdi+38h],eax
exit:
	jmp qword ptr [_cameraWrite3InterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
cameraWrite3Interceptor ENDP

resolutionScaleReadInterceptor PROC
;DevilMayCry5.exe+1920B933 - 48 8D 4C 24 40        - lea rcx,[rsp+40]
;DevilMayCry5.exe+1920B938 - C7 44 24 40 CDCCCC3D  - mov [rsp+40],3DCCCCCD { (0) }
;DevilMayCry5.exe+1920B940 - F3 0F10 80 6C120000   - movss xmm0,[rax+0000126C]				<< INTERCEPT HERE << READ Resolution scale. 
;DevilMayCry5.exe+1920B948 - 48 8D 44 24 3C        - lea rax,[rsp+3C]
;DevilMayCry5.exe+1920B94D - F3 41 0F59 46 40      - mulss xmm0,[r14+40]
;DevilMayCry5.exe+1920B953 - 0F2F C7               - comiss xmm0,xmm7						<< CONTINUE HERE
;DevilMayCry5.exe+1920B956 - F3 0F11 44 24 3C      - movss [rsp+3C],xmm0
;DevilMayCry5.exe+1920B95C - 48 0F46 C1            - cmovbe rax,rcx
;DevilMayCry5.exe+1920B960 - F3 0F10 08            - movss xmm1,[rax]
;DevilMayCry5.exe+1920B964 - 0F2F F1               - comiss xmm6,xmm1
;DevilMayCry5.exe+1920B967 - 77 03                 - ja DevilMayCry5.exe+1920B96C
;DevilMayCry5.exe+1920B969 - 0F28 CE               - movaps xmm1,xmm6
originalCode:
	mov [g_resolutionScaleAddress], rax
	movss xmm0, dword ptr [rax+0000126Ch]
	lea rax,[rsp+3Ch]
	mulss xmm0, dword ptr [r14+40h]
exit:
	jmp qword ptr [_resolutionScaleReadInterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
resolutionScaleReadInterceptor ENDP


timestopReadInterceptor PROC
; original
;DevilMayCry5.exe+179CA16D - 89 C1                 - mov ecx,eax
;DevilMayCry5.exe+179CA16F - F3 48 0F2A C1         - cvtsi2ss xmm0,rcx
;DevilMayCry5.exe+179CA174 - F3 0F58 C1            - addss xmm0,xmm1
;DevilMayCry5.exe+179CA178 - F3 0F11 87 88030000   - movss [rdi+00000388],xmm0
;DevilMayCry5.exe+179CA180 - C7 87 84030000 0000803F - mov [rdi+00000384],3F800000 { (0) }
;DevilMayCry5.exe+179CA18A - F3 0F10 97 A0030000   - movss xmm2,[rdi+000003A0]
;DevilMayCry5.exe+179CA192 - F3 0F10 87 84030000   - movss xmm0,[rdi+00000384]				<< INTERCEPT HERE
;DevilMayCry5.exe+179CA19A - 0F2F C2               - comiss xmm0,xmm2
;DevilMayCry5.exe+179CA19D - F3 0F10 9F 80030000   - movss xmm3,[rdi+00000380]				<< READ ADDRESS. SET TO 1.0 for normal procedure, 0.00001 otherwise.
;DevilMayCry5.exe+179CA1A5 - 76 03                 - jna DevilMayCry5.exe+179CA1AA			<< CONTINUE HERE
;DevilMayCry5.exe+179CA1A7 - 0F28 C2               - movaps xmm0,xmm2
;DevilMayCry5.exe+179CA1AA - F3 0F59 C3            - mulss xmm0,xmm3
;DevilMayCry5.exe+179CA1AE - 0F2F 87 A4030000      - comiss xmm0,[rdi+000003A4]
;DevilMayCry5.exe+179CA1B5 - F3 0F11 87 84030000   - movss [rdi+00000384],xmm0
;DevilMayCry5.exe+179CA1BD - 0F97 D0               - seta al
;DevilMayCry5.exe+179CA1C0 - 84 C0                 - test al,al
; 
; Update June 2019:
;DevilMayCry5.exe+17DF6615 - F3 0F10 8B 84030000   - movss xmm1,[rbx+00000384]				<< INTERCEPT HERE
;DevilMayCry5.exe+17DF661D - F3 0F10 83 84030000   - movss xmm0,[rbx+00000384]				<< READ ADDRESS. SET TO 1.0 for normal procedure, 0.00001 otherwise
;DevilMayCry5.exe+17DF6625 - F3 0F59 8B 80030000   - mulss xmm1,[rbx+00000380]
;DevilMayCry5.exe+17DF662D - 0F5A C0               - vcvtps2pd xmm0,xmm0					<< CONTINUE HERE
;DevilMayCry5.exe+17DF6630 - F3 0F11 8B 84030000   - movss [rbx+00000384],xmm1
;DevilMayCry5.exe+17DF6638 - F2 41 0F59 C1         - mulsd xmm0,xmm9
;DevilMayCry5.exe+17DF663D - F2 48 0F2C C0         - cvttsd2si rax,xmm0
;DevilMayCry5.exe+17DF6642 - 0F5A C1               - vcvtps2pd xmm0,xmm1
;DevilMayCry5.exe+17DF6645 - 48 01 C6              - add rsi,rax
;DevilMayCry5.exe+17DF6648 - F2 41 0F5E C0         - divsd xmm0,xmm8
;DevilMayCry5.exe+17DF664D - 66 0F5A C0            - cvtpd2ps xmm0,xmm0
;DevilMayCry5.exe+17DF6651 - F3 0F11 83 8C030000   - movss [rbx+0000038C],xmm0
	mov [g_timestopStructAddress], rbx
	movss xmm1, dword ptr [rbx+00000384h]
	movss xmm0, dword ptr [rbx+00000384h]
	mulss xmm1, dword ptr [rbx+00000380h]
exit:
	jmp qword ptr [_timestopReadInterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
timestopReadInterceptor ENDP

displayTypeInterceptor PROC
;DevilMayCry5.exe+17A16D9B - 72 06                 - jb DevilMayCry5.exe+17A16DA3
;DevilMayCry5.exe+17A16D9D - F3 44 0F11 43 48      - movss [rbx+48],xmm8
;DevilMayCry5.exe+17A16DA3 - 0F2F 43 4C            - comiss xmm0,[rbx+4C]
;DevilMayCry5.exe+17A16DA7 - 72 06                 - jb DevilMayCry5.exe+17A16DAF
;DevilMayCry5.exe+17A16DA9 - F3 44 0F11 4B 4C      - movss [rbx+4C],xmm9
;DevilMayCry5.exe+17A16DAF - F3 44 0F10 15 1053A7EC  - movss xmm10,[DevilMayCry5.exe+448C0C8]
;DevilMayCry5.exe+17A16DB8 - 48 8D 45 10           - lea rax,[rbp+10]
;DevilMayCry5.exe+17A16DBC - 48 89 45 18           - mov [rbp+18],rax
;DevilMayCry5.exe+17A16DC0 - 48 8D 3D 39925EE8     - lea rdi,[DevilMayCry5.exe]
;DevilMayCry5.exe+17A16DC7 - 8B 43 74              - mov eax,[rbx+74]							<< READ display type. Set to 0 for 'fit'. 
;DevilMayCry5.exe+17A16DCA - FF C8                 - dec eax
;DevilMayCry5.exe+17A16DCC - 83 F8 0F              - cmp eax,0F
;DevilMayCry5.exe+17A16DCF - 0F87 3B010000         - ja DevilMayCry5.exe+17A16F10
;DevilMayCry5.exe+17A16DD5 - 48 98                 - cdqe 
;DevilMayCry5.exe+17A16DD7 - 8B 8C 87 54A33E02     - mov ecx,[rdi+rax*4+023EA354]
;DevilMayCry5.exe+17A16DDE - 48 01 F9              - add rcx,rdi
;DevilMayCry5.exe+17A16DE1 - FF E1                 - jmp rcx
;
; We'll intercept a bit higher in the function as a RIP value is in the way, the RBX register is the same value:
;DevilMayCry5.exe+17A16D19 - 44 0F29 44 24 40      - movaps [rsp+40],xmm8						<< INTERCEPT HERE
;DevilMayCry5.exe+17A16D1F - 44 0F29 4C 24 30      - movaps [rsp+30],xmm9
;DevilMayCry5.exe+17A16D25 - F3 0F11 45 10         - movss [rbp+10],xmm0
;DevilMayCry5.exe+17A16D2A - F3 0F11 4D 14         - movss [rbp+14],xmm1						<< CONTINUE HERE
;DevilMayCry5.exe+17A16D2F - 44 0F29 54 24 20      - movaps [rsp+20],xmm10
;DevilMayCry5.exe+17A16D35 - 48 85 C9              - test rcx,rcx
	mov [g_displayTypeStructAddress], rbx
	movaps xmmword ptr [rsp+40h],xmm8
	movaps xmmword ptr [rsp+30h],xmm9
	movss dword ptr [rbp+10h],xmm0
exit:
	jmp qword ptr [_displayTypeInterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
displayTypeInterceptor ENDP


dofSelectorWriteInterceptor PROC
; use the whole block.
;DevilMayCry5.exe+194C5B30 - 89 51 4C              - mov [rcx+4C],edx					<< INTERCEPT HERE << DOF type write.
;DevilMayCry5.exe+194C5B33 - 85 D2                 - test edx,edx
;DevilMayCry5.exe+194C5B35 - 74 0E                 - je DevilMayCry5.exe+194C5B45
;DevilMayCry5.exe+194C5B37 - 83 EA 01              - sub edx,01
;DevilMayCry5.exe+194C5B3A - 74 09                 - je DevilMayCry5.exe+194C5B45
;DevilMayCry5.exe+194C5B3C - 83 FA 01              - cmp edx,01
;DevilMayCry5.exe+194C5B3F - 75 08                 - jne DevilMayCry5.exe+194C5B49
;DevilMayCry5.exe+194C5B41 - 88 51 50              - mov [rcx+50],dl
;DevilMayCry5.exe+194C5B44 - C3                    - ret								
;DevilMayCry5.exe+194C5B45 - C6 41 50 00           - mov byte ptr [rcx+50],00
;DevilMayCry5.exe+194C5B49 - C3                    - ret								<< CONTINUE HERE
	mov [g_dofStructAddress], rcx
	cmp byte ptr [g_cameraEnabled], 1
	je noWrite
	mov [rcx+4Ch],edx				
noWrite:
	test edx,edx
	je setToZero
	sub edx,01h
	je setToZero
	cmp edx,01h
	jne exit
	mov [rcx+50h],dl
	jmp exit
setToZero:
	mov byte ptr [rcx+50h],00
exit:
	jmp qword ptr [_dofSelectorWriteInterceptionContinue]	; jmp back into the original game code, which is the location after the original statements above.
dofSelectorWriteInterceptor ENDP

END