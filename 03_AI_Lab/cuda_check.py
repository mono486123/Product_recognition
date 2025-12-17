import torch

# 檢查 CUDA 是否可用 (指令的核心)
cuda_available = torch.cuda.is_available()
print(f"CUDA 是否可用: {cuda_available}")

# 如果可用，進一步查看裝置數量和名稱
if cuda_available:
    device_count = torch.cuda.device_count()
    print(f"可用的 GPU 數量: {device_count}")

    # 顯示第一張 GPU 的名稱
    gpu_name = torch.cuda.get_device_name(0)
    print(f"使用的 GPU 名稱: {gpu_name}")

else:
    print("❌ 警告：PyTorch 未偵測到 CUDA。訓練將在 CPU 上進行。")

exit()  # 離開 Python 互動模式