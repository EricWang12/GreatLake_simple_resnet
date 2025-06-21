import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms, models

# ----------  hyper-parameters ----------
batch_size = 256
lr          = 0.1
num_workers = 4         
epochs      = 5          
device      = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")

# ----------  dataset ----------
transform = transforms.Compose([
    transforms.Resize(224),        
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


# ----------  evaluation ----------
model.eval()
test_loader = torch.utils.data.DataLoader(
    datasets.CIFAR10(root="./data", train=False, download=True, transform=transform),
    batch_size=batch_size,
    shuffle=False,
    num_workers=num_workers,
    pin_memory=True,
)

correct = 0
total = 0
with torch.no_grad():
    for inputs, targets in test_loader:
        inputs, targets = inputs.to(device, non_blocking=True), targets.to(device, non_blocking=True)
        outputs = model(inputs)
        _, predicted = torch.max(outputs.data, 1)
        total += targets.size(0)
        correct += (predicted == targets).sum().item()

accuracy = 100 * correct / total
print(f"Test Accuracy: {accuracy:.2f}% ({correct}/{total})")
# Save the trained model
torch.save(model.state_dict(), 'resnet18_cifar10.pth')
print("Model saved to resnet18_cifar10.pth")



