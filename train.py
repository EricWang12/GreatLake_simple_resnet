import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms, models

# ----------  hyper-parameters ----------
batch_size = 128
lr          = 0.1
num_workers = 4          # adjust to your machine
epochs      = 1          # keep small for a quick demo
device      = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")

# ----------  dataset ----------
transform = transforms.Compose([
    transforms.Resize(224),        # ResNet expects 224×224
    transforms.ToTensor(),
    transforms.Normalize((0.5,)*3, (0.5,)*3)
])

train_loader = torch.utils.data.DataLoader(
    datasets.CIFAR10(root="./data", train=True, download=True, transform=transform),
    batch_size=batch_size,
    shuffle=True,
    num_workers=num_workers,
    pin_memory=True,
)

# ----------  model ----------
model = models.resnet18(weights=None, num_classes=10).to(device)

# loss & optimizer
criterion = nn.CrossEntropyLoss()
optimizer = optim.SGD(model.parameters(), lr=lr, momentum=0.9, weight_decay=5e-4)

# ----------  training loop ----------
model.train()
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

print("Finished.")
