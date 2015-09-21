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
__constant__ char password[5] = "Erin";


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
__device__ char *convertBase(long number_to_convert, int base) {
	   __shared__ int converted_number[8];
	   //char *converted_string = new char[8];
	   __shared__ char converted_string[8];
	   int index = 0;

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
	         converted_string[word_length - index] = converted_number[index]+(int)' ';
	   }

	   return converted_string;
}

/**
 * CUDA kernel that computes converts base 10 to any base
 * found this online somewhere
 */
__device__ void convertBase(char converted_string[], int converted_number[], int number_to_convert, int base) {
	   int index = 0;

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
	         converted_string[word_length - index] = converted_number[index]+(int)' ';
	   }
}

__global__ void universalCheckPasswordShared(char *return_guess, const int string_size, const int iteration) {
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	int total_threads = blockDim.x * gridDim.x;
	int codex = idx + (total_threads * iteration);
	int codex_for_printf = idx + (total_threads * iteration);
	const int base = (int)'~'+1;

	int converted_number[8];
	char converted_string[8];

    convertBase(converted_string, converted_number, codex, base);

	if(strcmpDevice(converted_string, password) == 0)
	{
		printf("%d,%d,%d,%d,%d,%d, %s == %s\n", codex_for_printf, blockIdx.x, blockDim.x, threadIdx.x, total_threads, iteration, converted_string, password);
		return_guess = strcpyDevice(return_guess, converted_string);
	}


}

/**
 * Host function that copies the data and launches the work on GPU
 * Created n streams where n = number of multiprocessors * 8 (peformance degrades after this point on my GTX)
 * thread count per kernel is your max threads / 2
 * block count is the number of multiprocessors you have
 * Using shared register memory I have been measuring about 32,499,876 password generations and comparisons per second
 */
char *checkPasswordHost(int iteration)
{
	cudaSetDevice(0);
	cudaDeviceProp deviceProp;
	cudaGetDeviceProperties(&deviceProp, 0);

	int STREAM_COUNT = deviceProp.multiProcessorCount * 8;
	cudaStream_t streams[STREAM_COUNT];

	for(int i = 0; i < STREAM_COUNT; ++i)
	{
		cudaStreamCreate(&streams[i]);
	}

	static const int THREAD_COUNT = deviceProp.maxThreadsPerMultiProcessor / 2;
	static const int BLOCK_COUNT = deviceProp.multiProcessorCount;
	//static const int THREAD_COUNT = 1024;
	//static const int BLOCK_COUNT = 16;
	static const int TOTAL_THREADS = THREAD_COUNT * BLOCK_COUNT;
	static const int SIZE = 8;
	char *converted_string = new char[SIZE];
	char **converted_strings;
	int **converted_numbers;
	// This is the variable that the data will be reutrned to.  It is shared amongst all the threads and streams.
	char *gpuData;

	for(int i = 0; i < SIZE; ++i)
		converted_string[i] = '\0';

	CUDA_CHECK_RETURN(cudaMalloc((void **)&converted_strings, sizeof(char*)*TOTAL_THREADS));
	CUDA_CHECK_RETURN(cudaMalloc((void **)&converted_numbers, sizeof(int*)*TOTAL_THREADS));
	CUDA_CHECK_RETURN(cudaMalloc((void **)&gpuData, sizeof(char)*SIZE));
	CUDA_CHECK_RETURN(cudaMemcpy(gpuData, converted_string, sizeof(char)*SIZE, cudaMemcpyHostToDevice));

	for(int i = 0; i < STREAM_COUNT; ++i)
	{
		universalCheckPasswordShared<<<BLOCK_COUNT, THREAD_COUNT, 0, streams[i]>>> (gpuData, SIZE, (iteration * STREAM_COUNT) + i);
	}

	for(int i = 0; i < STREAM_COUNT; ++i)
	{
		cudaStreamSynchronize(streams[i]);
		cudaStreamDestroy(streams[i]);
	}

	CUDA_CHECK_RETURN(cudaMemcpy(converted_string, gpuData, sizeof(char)*SIZE, cudaMemcpyDeviceToHost));
	CUDA_CHECK_RETURN(cudaFree(gpuData));
	CUDA_CHECK_RETURN(cudaFree(converted_strings));
	CUDA_CHECK_RETURN(cudaFree(converted_numbers));
	return converted_string;
}

int main(void)
{
	time_t start = time(0);
    int iteration = 0;
    int max_iterations = 1000000;
    char *answer_password;
    answer_password = new char[1];
    answer_password[0] = '\0';

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

