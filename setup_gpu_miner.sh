#!/bin/bash
# Stop script if any command fails
set -e

echo "===> Installing dos2unix and preparing script..."
apt-get install -y dos2unix && dos2unix setup_gpu_miner.sh && chmod +x setup_gpu_miner.sh

echo "===> Updating and installing basic dependencies..."
apt-get update
apt-get install -y sudo g++ make git nano curl clinfo dos2unix screen

echo "===> Installing OpenCL libraries..."
apt-get install -y ocl-icd-opencl-dev libopencl-clang-dev

echo "===> Installing Python 3.10 and pip..."
apt-get install -y python3.10 python3.10-dev python3.10-venv python3.10-distutils python3-pip

echo "===> Setting Python 3.10 as default..."
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

echo "===> Upgrading pip..."
python3 -m pip install --upgrade pip

echo "===> Installing pybind11 library..."
apt-get install -y pybind11-dev
python3 -m pip install pybind11

echo "===> Cloning gpu-miner repository..."
git clone https://github.com/ricoita24/gpu-miner.git
cd gpu-miner

echo "===> Exporting C++ include path for pybind11..."
export CPLUS_INCLUDE_PATH=$CPLUS_INCLUDE_PATH:/usr/local/lib/python3.10/dist-packages/pybind11/include

echo "===> Setting up OpenCL vendor for NVIDIA..."
mkdir -p /etc/OpenCL/vendors
echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd

echo "===> Building gpu-miner..."
make clean
make

echo "===> Creating Python 3.10 virtual environment..."
python3 -m venv myenv

echo "===> Creating requirements.txt file..."
cat <<EOF > requirements.txt
pybind11
safe-pysha3
ecdsa
web3
coincurve
websocket-client
websockets
python-dotenv
EOF

echo "===> Installing Python dependencies in virtual environment..."
./myenv/bin/pip install --upgrade pip
./myenv/bin/pip install -r requirements.txt

echo "===> Creating empty .env file..."
touch .env

echo "===> Testing OpenCL kernel..."
./myenv/bin/python test_opencl_kernel.py

echo "===> Creating automatic activation script..."
cat > /usr/local/bin/start-gpu-miner <<EOF
#!/bin/bash
cd gpu-miner
source myenv/bin/activate
exec bash
EOF
chmod +x /usr/local/bin/start-gpu-miner

# Create a simple finish script in the starting directory
cat > finish_setup.sh <<EOF
#!/bin/bash
cd gpu-miner
source myenv/bin/activate
touch .env
echo ""
echo "===> Virtual environment activated!"
echo "===> You are now in the gpu-miner directory."
echo "===> Empty .env file created."
echo "===> Ready to use the GPU miner."
echo ""
# Check if screen session exists, if not create it
if ! screen -list | grep -q "gpu-miner"; then
  echo "===> Creating and attaching to screen session 'gpu-miner'..."
  screen -dmS gpu-miner
  screen -r gpu-miner
else
  echo "===> Attaching to existing screen session 'gpu-miner'..."
  screen -r gpu-miner
fi
EOF
chmod +x finish_setup.sh

# Create a script to start miner in screen
cat > /usr/local/bin/start-gpu-miner-screen <<EOF
#!/bin/bash
cd gpu-miner
source myenv/bin/activate
# Check if screen session exists, if not create it
if ! screen -list | grep -q "gpu-miner"; then
  screen -dmS gpu-miner
fi
# Attach to the screen session
screen -r gpu-miner
EOF
chmod +x /usr/local/bin/start-gpu-miner-screen

echo "===> Setup complete!"
echo ""
echo "===> To complete setup, run this command:"
echo "     source ./finish_setup.sh"
echo ""
echo "===> In the future, you can start the miner in a screen session with:"
echo "     start-gpu-miner-screen"
echo ""
