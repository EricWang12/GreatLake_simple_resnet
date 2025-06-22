#!/usr/bin/env python
# multi_gpu_resnet.py
# Train ResNet-18 on CIFAR-10 using all visible GPUs (DataParallel).

import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms, models
import os
import time

# ---------- hyper-parameters ----------
batch_size   = 512
lr           = 0.1
epochs       = 10
device       = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# ---------- data ----------
transform = transforms.Compose([
    transforms.Resize(224),
    transforms.ToTensor(),
    transforms.Normalize((0.5,)*3, (0.5,)*3),
])

train_loader = torch.utils.data.DataLoader(
    datasets.CIFAR10(root="./data", train=True, download=True, transform=transform),
    batch_size=batch_size,
    shuffle=True,
    num_workers=os.cpu_count(),
    pin_memory=True,
)

# ---------- model ----------
model = models.resnet18(weights=None, num_classes=10)

# wrap with DataParallel if >1 GPU
if torch.cuda.device_count() > 1:
    print(f"Using {torch.cuda.device_count()} GPUs")
    model = nn.DataParallel(model)

model = model.to(device)

# loss & optimizer
criterion  = nn.CrossEntropyLoss()
optimizer  = optim.SGD(model.parameters(), lr=lr, momentum=0.9, weight_decay=5e-4)

# ---------- training ----------
model.train()

start_time = time.time()
for epoch in range(epochs):
    running_loss = 0.0
    for i, (inputs, targets) in enumerate(train_loader):
        inputs, targets = inputs.to(device, non_blocking=True), targets.to(device, non_blocking=True)

        optimizer.zero_grad()
        outputs = model(inputs)
        loss    = criterion(outputs, targets)
        loss.backward()
        optimizer.step()

        running_loss += loss.item()
        if (i + 1) % 50 == 0:
            print(f"[{epoch+1}/{epochs}] step {i+1:4d}/{len(train_loader)}  "
                  f"loss: {running_loss / 50:.4f}")
            running_loss = 0.0

print("Training finished.")
training_time = time.time() - start_time

# ---------- evaluation ----------
test_loader = torch.utils.data.DataLoader(
    datasets.CIFAR10(root="./data", train=False, download=True, transform=transform),
    batch_size=batch_size,
    shuffle=False,
    num_workers=num_workers,
    pin_memory=True,
)

model.eval()
correct = 0
total   = 0
with torch.no_grad():
    for inputs, targets in test_loader:
        inputs, targets = inputs.to(device, non_blocking=True), targets.to(device, non_blocking=True)
        outputs = model(inputs)
        _, predicted = torch.max(outputs.data, 1)
        total   += targets.size(0)
        correct += (predicted == targets).sum().item()

acc = 100.0 * correct / total
print(f"Test Accuracy: {acc:.2f}% ({correct}/{total})")

# Print total training time
print(f"Total training time: {training_time:.2f} seconds")
# ---------- save ----------
torch.save(model.state_dict(), f"resnet18_cifar10_gpu_{torch.cuda.device_count()}.pth")
print( f"resnet18_cifar10_gpu_{torch.cuda.device_count()}.pth")
