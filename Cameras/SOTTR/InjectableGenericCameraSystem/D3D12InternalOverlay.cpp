#include "stdafx.h"
#include <d3d12.h> 
#include <dxgi1_4.h>
#include "D3D12InternalOverlay.h"
#include "Console.h"
#include "MinHook.h"
#include "Globals.h"
#include "imgui.h"
#include "Defaults.h"
#include "imgui_impl_dx12.h"
#include "imgui_impl_win32.h"
#include "OverlayControl.h"
#include "OverlayConsole.h"
#include "Input.h"
#include <atomic>
#include <sstream>

#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "dxgi.lib")

///////////////////////
// Defines hooks and render code for an internal overlay, using DX12. For DX12 games, use this internal overlay to have a nice overlay in the same viewport as
// the game.
///////////////////////
namespace IGCS::D3D12InternalOverlay
{
	#define DXGI_PRESENT_INDEX			8
	#define DXGI_RESIZEBUFFERS_INDEX	13

	//--------------------------------------------------------------------------------------------------------------------------------
	// Forward declarations
	void createRenderTarget(IDXGISwapChain * pSwapChain);
	void cleanupRenderTarget();
	void initD3D12Structures(IDXGISwapChain* pSwapChain);
	void setTransitionState(ID3D12Resource* resource, D3D12_RESOURCE_STATES from, D3D12_RESOURCE_STATES to);

	//--------------------------------------------------------------------------------------------------------------------------------
	// Typedefs of functions to hook
	typedef HRESULT(__stdcall* DXGIPresentHook) (IDXGISwapChain* pSwapChain, UINT SyncInterval, UINT Flags);
	typedef HRESULT(__stdcall* DXGIResizeBuffersHook) (IDXGISwapChain* pSwapChain, UINT bufferCount, UINT width, UINT height, DXGI_FORMAT newFormat, UINT swapChainFlags);

	static ID3D12CommandAllocator* _commandAllocators[10] = {}; // should be enough.
	static ID3D12Device* _device = nullptr;
	static ID3D12DescriptorHeap* _rtvDescHeap = nullptr;
	static ID3D12DescriptorHeap* _srvDescHeap = nullptr;
	static ID3D12CommandQueue* _commandQueue = nullptr;
	static ID3D12GraphicsCommandList* _commandList = nullptr;
	static D3D12_CPU_DESCRIPTOR_HANDLE  _mainRenderTargetDescriptors[10] = {}; // should be enough.
	static ID3D12Resource* _mainRenderTargetResources[10] = {};	// should be enough.
	static UINT _numberOfBuffersInFlight = 10;

	//--------------------------------------------------------------------------------------------------------------------------------
	// Pointers to the original hooked functions
	static DXGIPresentHook hookedDXGIPresent = nullptr;
	static DXGIResizeBuffersHook hookedDXGIResizeBuffers = nullptr;

	static bool _tmpSwapChainInitialized = false;
	static atomic_bool _imGuiInitializing = false;
	static atomic_bool _initializeD3D12Structures = true;
	static atomic_bool _presentInProgress = false;

	HRESULT __stdcall detourDXGIResizeBuffers(IDXGISwapChain* pSwapChain, UINT bufferCount, UINT width, UINT height, DXGI_FORMAT newFormat, UINT swapChainFlags)
	{
		_imGuiInitializing = true;
		ImGui_ImplDX12_InvalidateDeviceObjects();
		cleanupRenderTarget();
		HRESULT toReturn = hookedDXGIResizeBuffers(pSwapChain, bufferCount, width, height, newFormat, swapChainFlags);
		createRenderTarget(pSwapChain);
		ImGui_ImplDX12_CreateDeviceObjects();
		_imGuiInitializing = false;
		return toReturn;
	}


	HRESULT __stdcall detourDXGIPresent(IDXGISwapChain* pSwapChain, UINT SyncInterval, UINT Flags)
	{
		if (_presentInProgress)
		{
			return S_OK;
		}
		_presentInProgress = true;
		if (_tmpSwapChainInitialized)
		{
			if (!(Flags & DXGI_PRESENT_TEST) && !_imGuiInitializing)
			{
				if (_initializeD3D12Structures)
				{
					initD3D12Structures(pSwapChain);
				}
				// render our own stuff
				OverlayControl::renderOverlay();
				// d3d12 rendering code. 
				IDXGISwapChain3* pSwapChain3 = nullptr;
				pSwapChain->QueryInterface(IID_PPV_ARGS(&pSwapChain3));
				UINT backBufferIdx = pSwapChain3->GetCurrentBackBufferIndex();
				pSwapChain3->Release();
				_commandAllocators[backBufferIdx]->Reset();
				setTransitionState(_mainRenderTargetResources[backBufferIdx], D3D12_RESOURCE_STATE_PRESENT, D3D12_RESOURCE_STATE_RENDER_TARGET);
				_commandList->Reset(_commandAllocators[backBufferIdx], NULL);
				_commandList->OMSetRenderTargets(1, &_mainRenderTargetDescriptors[backBufferIdx], FALSE, NULL);
				_commandList->SetDescriptorHeaps(1, &_srvDescHeap);
				ImGui_ImplDX12_RenderDrawData(ImGui::GetDrawData(), _commandList);
				setTransitionState(_mainRenderTargetResources[backBufferIdx], D3D12_RESOURCE_STATE_RENDER_TARGET, D3D12_RESOURCE_STATE_PRESENT);
				_commandList->Close();
				_commandQueue->ExecuteCommandLists(1, (ID3D12CommandList * const*)& _commandList);
				Input::resetKeyStates();
				Input::resetMouseState();
			}
		}
		HRESULT toReturn = hookedDXGIPresent(pSwapChain, SyncInterval, Flags);
		_presentInProgress = false;
		return toReturn;
	}


	void setTransitionState(ID3D12Resource* resource, D3D12_RESOURCE_STATES from, D3D12_RESOURCE_STATES to)
	{
		D3D12_RESOURCE_BARRIER transition = { D3D12_RESOURCE_BARRIER_TYPE_TRANSITION };
		transition.Transition.pResource = resource;
		transition.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
		transition.Transition.StateBefore = from;
		transition.Transition.StateAfter = to;
		_commandList->ResourceBarrier(1, &transition);
	}


	LRESULT WINAPI WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
	{
		return DefWindowProc(hWnd, msg, wParam, lParam);
	}

	void initializeHook()
	{
		// Create tmp window. We initialize the swapchain on this window. As we own this swapchain we won't run into access denied issues if the swapchain is
		// exclusive to the window of the game. 
		WNDCLASSEX wc = { sizeof(WNDCLASSEX), CS_CLASSDC, WndProc, 0L, 0L, GetModuleHandle(NULL), NULL, NULL, NULL, NULL, _T("IGCS TmpWindow"), NULL };
		::RegisterClassEx(&wc);
		HWND hwnd = ::CreateWindow(wc.lpszClassName, _T("IGCS TmpWindow"), WS_OVERLAPPEDWINDOW, 100, 100, 100, 100, NULL, NULL, wc.hInstance, NULL);

		_tmpSwapChainInitialized = false;
		D3D_FEATURE_LEVEL featureLevel = D3D_FEATURE_LEVEL_11_0;

		IDXGIFactory4* pTmpDXGIFactory;
		if (FAILED(CreateDXGIFactory1(IID_PPV_ARGS(&pTmpDXGIFactory))))
		{
			IGCS::Console::WriteError("Failed to create DXGI Factory! You're running the Direct3D11 version of the game?");
			return;
		}

		IDXGIAdapter* pTmpAdapter;
		pTmpDXGIFactory->EnumAdapters(0, &pTmpAdapter);

		// create the d3d12 device
		ID3D12Device* pTmpDevice;
		if (FAILED(D3D12CreateDevice(pTmpAdapter, featureLevel, IID_PPV_ARGS(&pTmpDevice))))
		{
			IGCS::Console::WriteError("Failed to create D3D12Device! You're running the Direct3D11 version of the game?");
			return;
		}

		// create the command queue from the device
		ID3D12CommandQueue* pTmpCommandQueue;
		D3D12_COMMAND_QUEUE_DESC commandQueueDesc = {};
		commandQueueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
		commandQueueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
		if (FAILED(pTmpDevice->CreateCommandQueue(&commandQueueDesc, IID_PPV_ARGS(&pTmpCommandQueue))))
		{
			IGCS::Console::WriteError("Failed to create D3D12CommandQueue! You're running the Direct3D11 version of the game?");
			return;
		}

		// THEN create the swapchain, passing the commandqueue
		DXGI_SWAP_CHAIN_DESC swapChainDesc;
		ZeroMemory(&swapChainDesc, sizeof(swapChainDesc));
		swapChainDesc.BufferCount = 2;
		swapChainDesc.BufferDesc.Width = 0;
		swapChainDesc.BufferDesc.Height = 0;
		swapChainDesc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
		swapChainDesc.BufferDesc.RefreshRate.Numerator = 60;
		swapChainDesc.BufferDesc.RefreshRate.Denominator = 1;
		swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
		swapChainDesc.OutputWindow = hwnd;
		swapChainDesc.SampleDesc.Count = 1;
		swapChainDesc.SampleDesc.Quality = 0;
		swapChainDesc.Windowed = TRUE;
		swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;

		IDXGISwapChain* pTmpSwapChain;
		if (FAILED(pTmpDXGIFactory->CreateSwapChain(pTmpCommandQueue, &swapChainDesc, &pTmpSwapChain)))
		{
			IGCS::Console::WriteError("Failed to create Direct3D 12 SwapChain! You're running the Direct3D11 version of the game?");
			return;
		}

		__int64* pSwapChainVtable = NULL;
		pSwapChainVtable = (__int64*)pTmpSwapChain;
		pSwapChainVtable = (__int64*)pSwapChainVtable[0];

		OverlayConsole::instance().logDebug("Present Address: %p", (void*)(__int64*)pSwapChainVtable[DXGI_PRESENT_INDEX]);

		if (MH_CreateHook((LPBYTE)pSwapChainVtable[DXGI_PRESENT_INDEX], &detourDXGIPresent, reinterpret_cast<LPVOID*>(&hookedDXGIPresent)) != MH_OK)
		{
			IGCS::Console::WriteError("Hooking Present failed!");
		}
		if (MH_EnableHook((LPBYTE)pSwapChainVtable[DXGI_PRESENT_INDEX]) != MH_OK)
		{
			IGCS::Console::WriteError("Enabling of Present hook failed!");
		}

		OverlayConsole::instance().logDebug("ResizeBuffers Address: %p", (__int64*)pSwapChainVtable[DXGI_RESIZEBUFFERS_INDEX]);

		if (MH_CreateHook((LPBYTE)pSwapChainVtable[DXGI_RESIZEBUFFERS_INDEX], &detourDXGIResizeBuffers, reinterpret_cast<LPVOID*>(&hookedDXGIResizeBuffers)) != MH_OK)
		{
			IGCS::Console::WriteError("Hooking ResizeBuffers failed!");
		}
		if (MH_EnableHook((LPBYTE)pSwapChainVtable[DXGI_RESIZEBUFFERS_INDEX]) != MH_OK)
		{
			IGCS::Console::WriteError("Enabling of ResizeBuffers hook failed!");
		}

		pTmpCommandQueue->Release();
		pTmpDevice->Release();
		pTmpSwapChain->Release();

		CloseWindow(hwnd);

		_tmpSwapChainInitialized = true;

		OverlayConsole::instance().logDebug("DX12 hooks set");
	}


	void initD3D12Structures(IDXGISwapChain* pSwapChain)
	{
		if (!_initializeD3D12Structures)
		{
			return;
		}
		if (FAILED(pSwapChain->GetDevice(IID_PPV_ARGS(&_device))))
		{
			IGCS::Console::WriteError("Failed to get device from hooked swapchain");
			return;
		}

		DXGI_SWAP_CHAIN_DESC desc;
		pSwapChain->GetDesc(&desc);
		_numberOfBuffersInFlight = desc.BufferCount;
		if (_numberOfBuffersInFlight > 10)
		{
			_numberOfBuffersInFlight = 10;
		}

		OverlayConsole::instance().logDebug("DX12 Device: %p", (void*)_device);
		// create rtv descriptor heap
		D3D12_DESCRIPTOR_HEAP_DESC rtvDescriptorHeapDesc = {};
		rtvDescriptorHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
		rtvDescriptorHeapDesc.NumDescriptors = _numberOfBuffersInFlight;
		rtvDescriptorHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
		rtvDescriptorHeapDesc.NodeMask = 0;
		if (FAILED(_device->CreateDescriptorHeap(&rtvDescriptorHeapDesc, IID_PPV_ARGS(&_rtvDescHeap))))
		{
			IGCS::Console::WriteError("Failed to create RTV descriptor heap");
			return;
		}

		OverlayConsole::instance().logDebug("RTV ID3D12DescriptorHeap: %p", (void*)_rtvDescHeap);

		SIZE_T rtvDescriptorSize = _device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
		D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle = _rtvDescHeap->GetCPUDescriptorHandleForHeapStart();
		for (int i = 0; i < _numberOfBuffersInFlight; i++)
		{
			_mainRenderTargetDescriptors[i] = rtvHandle;
			rtvHandle.ptr += rtvDescriptorSize;
		}

		// create srv descriptor heap
		D3D12_DESCRIPTOR_HEAP_DESC srvDescriptorHeapDesc = {};
		srvDescriptorHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
		srvDescriptorHeapDesc.NumDescriptors = 1;
		srvDescriptorHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
		if (FAILED(_device->CreateDescriptorHeap(&srvDescriptorHeapDesc, IID_PPV_ARGS(&_srvDescHeap))))
		{
			IGCS::Console::WriteError("Failed to create SRV descriptor heap");
		}
		OverlayConsole::instance().logDebug("SRV ID3D12DescriptorHeap: %p", (void*)_srvDescHeap);

		// create command queue
		D3D12_COMMAND_QUEUE_DESC commandQueueDesc = {};
		commandQueueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
		commandQueueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
		commandQueueDesc.NodeMask = 0;
		if (FAILED(_device->CreateCommandQueue(&commandQueueDesc, IID_PPV_ARGS(&_commandQueue))))
		{
			IGCS::Console::WriteError("Failed to create D3D12CommandQueue");
		}
		OverlayConsole::instance().logDebug("ID3D12CommandQueue: %p", (void*)_commandQueue);

		// create command allocators
		for (int i = 0; i < _numberOfBuffersInFlight; i++)
		{
			if (FAILED(_device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&_commandAllocators[i]))))
			{
				IGCS::Console::WriteError("Failed to create D3D12CommandAllocator");
			}
			OverlayConsole::instance().logDebug("ID3D12CommandAllocator %d: %p", i, (void*)_commandAllocators[i]);
		}
		// create command list 
		if (FAILED(_device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, _commandAllocators[0], NULL, IID_PPV_ARGS(&_commandList))))
		{
			IGCS::Console::WriteError("Failed to create D3D12CommandList");
		}
		OverlayConsole::instance().logDebug("ID3D12CommandList: %p", (void*)_commandList);

		createRenderTarget(pSwapChain);
		ImGui_ImplDX12_Init(_device, _numberOfBuffersInFlight, DXGI_FORMAT_R8G8B8A8_UNORM, _srvDescHeap->GetCPUDescriptorHandleForHeapStart(), _srvDescHeap->GetGPUDescriptorHandleForHeapStart());
		_initializeD3D12Structures = false;

		// *pfew!* finally we've created all the objects D3D12 needs, using a convoluted set of interfaces. If only they had the power to design the interfaces themselves! 
	}


	void createRenderTarget(IDXGISwapChain* pSwapChain)
	{
		for (int i = 0; i < _numberOfBuffersInFlight; i++)
		{
			_mainRenderTargetResources[i] = nullptr;
		}
		ID3D12Resource* pBackBuffer;
		for (int i = 0; i < _numberOfBuffersInFlight; i++)
		{
			pSwapChain->GetBuffer(i, IID_PPV_ARGS(&pBackBuffer));
			_device->CreateRenderTargetView(pBackBuffer, NULL, _mainRenderTargetDescriptors[i]);
			_mainRenderTargetResources[i] = pBackBuffer;
		}
	}


	void cleanupRenderTarget()
	{
		for (int i = 0; i < _numberOfBuffersInFlight; i++)
		{
			if (nullptr != _mainRenderTargetResources[i])
			{
				_mainRenderTargetResources[i]->Release();
				_mainRenderTargetResources[i] = nullptr;
			}
		}
	}
}