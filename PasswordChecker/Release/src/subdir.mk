################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
CU_SRCS += \
../src/PasswordChecker.cu 

CU_DEPS += \
./src/PasswordChecker.d 

OBJS += \
./src/PasswordChecker.o 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.cu
	@echo 'Building file: $<'
	@echo 'Invoking: NVCC Compiler'
	/usr/local/cuda-7.5/bin/nvcc -O3 -gencode arch=compute_20,code=sm_20 -gencode arch=compute_20,code=sm_21 -gencode arch=compute_52,code=sm_52 -m64 -odir "src" -M -o "$(@:%.o=%.d)" "$<"
	/usr/local/cuda-7.5/bin/nvcc -O3 --compile --relocatable-device-code=false -gencode arch=compute_20,code=compute_20 -gencode arch=compute_52,code=compute_52 -gencode arch=compute_20,code=sm_21 -gencode arch=compute_52,code=sm_52 -m64  -x cu -o  "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


