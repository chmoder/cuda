Example Compilation
15:53:44 **** Incremental Build of configuration Debug for project PasswordChecker ****
make all 
Building file: ../src/PasswordChecker.cu
Invoking: NVCC Compiler
/usr/local/cuda-7.5/bin/nvcc -G -g -O0 -gencode arch=compute_52,code=sm_52 -m64 -odir "src" -M -o "src/PasswordChecker.d" "../src/PasswordChecker.cu"
/usr/local/cuda-7.5/bin/nvcc -G -g -O0 --compile --relocatable-device-code=false -gencode arch=compute_52,code=compute_52 -gencode arch=compute_52,code=sm_52 -m64  -x cu -o  "src/PasswordChecker.o" "../src/PasswordChecker.cu"
Finished building: ../src/PasswordChecker.cu
 
Building target: PasswordChecker
Invoking: NVCC Linker
/usr/local/cuda-7.5/bin/nvcc --cudart static --relocatable-device-code=false -gencode arch=compute_52,code=compute_52 -gencode arch=compute_52,code=sm_52 -m64 -link -o  "PasswordChecker"  ./src/PasswordChecker.o   
Finished building target: PasswordChecker

This CUDA code as been checking arround 32,499,876 passwords per second
