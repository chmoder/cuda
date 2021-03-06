/*
 ============================================================================
 Name        : PasswordChecker.cu
 Author      : Thomas Cross
 Version     : 0.0.1
 Copyright   : This is free.  Do with it as you please
 Description : CUDA password generator and checker
 ============================================================================
 */

#include <iostream>
#include <numeric>
#include <stdlib.h>
#include <stdio.h>
#include <cmath>

static void CheckCudaErrorAux (const char *, unsigned, const char *, cudaError_t);
#define CUDA_CHECK_RETURN(value) CheckCudaErrorAux(__FILE__,__LINE__, #value, value)

/*
 * The password in question
 * */
__constant__ char password[16];
__constant__ char alphabet[95];

/**
 * CUDA kernel copies one string buffer to another
 */
__device__ char *strcpyDevice(char *dest, const char *src)
{
    char *ret = dest;
    while (*dest++ = *src++)
        ;
    return ret;
}

/**
 * CUDA kernel that compares two strings
 */
__device__ int strcmpDevice(const char * s1, const char * s2)
{
	while(*s1 && (*s1==*s2))
	{
		s1++,s2++;
	}
	return *(const unsigned char*)s1-*(const unsigned char*)s2;
}

/**
 * CUDA kernel that computes converts base 10 to any base
 * found this online somewhere
 */
__device__ void convertBase(char converted_string[], int converted_number[], unsigned long long number_to_convert, int base, char *alphabet) {
	//char alphabet[95] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '!', '"', '#', '$', '%', '&', "'", '(', ')', '*', '+', ',', '-', '.', '/', ':', ';', '<', '=', '>', '?', '@', '[', '\\', ']', '^', '_', '`', '{', '|', '}', '~', ' '};
	//char *alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!\"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~ ";
	int index = 0;
	base = 95;

	/* convert to the indicated base */
	while (number_to_convert != 0)
	{
		converted_number[index] = number_to_convert % base;
		number_to_convert = number_to_convert / base;
		++index;
	}
	converted_string[index] = '\0';

	/* now print the result in reverse order */
	--index;  /* back up to last entry in the array */
	int word_length = index;
	for(  ; index>=0; index--) /* go backward through array */
	{
		converted_string[word_length - index] = alphabet[converted_number[index]];
	}
}

__global__ void checkPasswordShared(char *return_guess, const int string_size, const int iteration) {
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	int total_threads = blockDim.x * gridDim.x;
	int converted_number[16];
	char converted_string[16];
	unsigned long long codex = idx + (total_threads * iteration);
	unsigned long long codex_for_printf = idx + (total_threads * iteration);
	const int base = (int)'z';

    convertBase(converted_string, converted_number, codex, base, alphabet);

	if(strcmpDevice(converted_string, password) == 0)
	{
		printf("%llu,%d,%d,%d,%d,%d, %s == %s\n", codex_for_printf, blockIdx.x, blockDim.x, threadIdx.x, total_threads, iteration, converted_string, password);
		return_guess = strcpyDevice(return_guess, converted_string);
	}
}

/**
 * Host function that copies the data and launches the work on GPU
 * Created n streams where n = number of multiprocessors * 8 (peformance degrades after this point on my GTX)
 * thread count per kernel is your max threads / 2
 * block count is the number of multiprocessors you have
 * Using shared memory and registers I have been measuring about 32,499,876 password generations and comparisons per second
 */
char *checkPasswordHost(int iteration)
{
	cudaSetDevice(0);
	cudaDeviceProp deviceProp;
	cudaGetDeviceProperties(&deviceProp, 0);

	int STREAM_COUNT = deviceProp.multiProcessorCount * 8 * 8;
	cudaStream_t streams[STREAM_COUNT];

	for(int i = 0; i < STREAM_COUNT; ++i)
	{
		cudaStreamCreate(&streams[i]);
	}

	static const int THREAD_COUNT = deviceProp.maxThreadsPerMultiProcessor / 2;
	static const int BLOCK_COUNT = deviceProp.multiProcessorCount;
	static const int SIZE = 16;
	char *converted_string = new char[SIZE];
	char *gpuData;

	for(int i = 0; i < SIZE; ++i)
		converted_string[i] = '\0';

	CUDA_CHECK_RETURN(cudaMalloc((void **)&gpuData, sizeof(char)*SIZE));
	CUDA_CHECK_RETURN(cudaMemcpy(gpuData, converted_string, sizeof(char)*SIZE, cudaMemcpyHostToDevice));

	for(int i = 0; i < STREAM_COUNT; ++i)
	{
		checkPasswordShared<<<BLOCK_COUNT, THREAD_COUNT, 0, streams[i]>>> (gpuData, SIZE, (iteration * STREAM_COUNT) + i);
	}

	for(int i = 0; i < STREAM_COUNT; ++i)
	{
		cudaStreamSynchronize(streams[i]);
		cudaStreamDestroy(streams[i]);
	}

	CUDA_CHECK_RETURN(cudaMemcpy(converted_string, gpuData, sizeof(char)*SIZE, cudaMemcpyDeviceToHost));
	CUDA_CHECK_RETURN(cudaFree(gpuData));
	return converted_string;
}

int main(void)
{
    int iteration = 0;
    int max_iterations = 100000000;
    char *answer_password;
    answer_password = new char[1];
    answer_password[0] = '\0';
    std::string temp_password;

	std::cout << "Please enter a password to find: ";
	getline(std::cin, temp_password);
	CUDA_CHECK_RETURN(cudaMemcpyToSymbol(password, temp_password.c_str(), sizeof(char) * 16));
	CUDA_CHECK_RETURN(cudaMemcpyToSymbol(alphabet, "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!\"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~ ", sizeof(char) * 95));
	std::cout << "searching for \"" << temp_password.c_str() << "\"..." << std::endl;

	time_t start = time(0);
    while(answer_password[0] == '\0' && iteration < max_iterations)
	{
		delete[] answer_password;
		answer_password = checkPasswordHost(iteration);
    	//std::cout << "The password could be: \"" << answer_password << "\"" << std::endl;
		iteration++;
	}

    if(answer_password[0] != '\0')
    {
    	std::cout << "The password is: \"" << answer_password << "\"" << std::endl;
    }
    else if(iteration == max_iterations)
    {
    	std::cout << "Reached max iterations of " << max_iterations << std::endl;
    }

	time_t end = time(0);
	double time = difftime(end, start);
	std::cout << "Execution Time: " << (int)floor(time) << " seconds" << std::endl;

	delete[] answer_password;

	return 0;
}

/**
 * Check the return value of the CUDA runtime API call and exit
 * the application if the call has failed.
 */
static void CheckCudaErrorAux (const char *file, unsigned line, const char *statement, cudaError_t err)
{
	if (err == cudaSuccess)
		return;
	std::cerr << statement<<" returned " << cudaGetErrorString(err) << "("<<err<< ") at "<<file<<":"<<line << std::endl;
	exit (1);
}
