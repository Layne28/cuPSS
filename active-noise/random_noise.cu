/* Short explanation on the way to add fields and terms in this file
 *
 * evolver is a class that merely calls updates on all fields and terms
 * the arguments on its constructor are 
 *
 *      evolver system(x,           sx,             sy,             dx,       dy,       dt);
 *                     Use CUDA | x-system size | y-system size | delta_x | delta_y | delta_t
 *
 * To this evolver we can add fields:
 *
 *      system.createField( name, dynamic );
 *
 * name is a string and dynamic if a boolean that sets whether the field
 * is set in each step through a time derivative or through an equality.
 *
 * To each field we can add terms
 *      
 *      system.createTerm(  field_name, prefactor, {field_1, ..., field_n}  );
 *
 *  This term would be a term of "field_name", with that prefactor, that multiplies
 *  fields field_1 to field_n.
 */ 

#include <cmath>
#include <cstdlib>
#include <cuda_runtime_api.h>
#include <driver_types.h>
#include <iostream>
#include <ostream>
#include "../inc/defines.h"
#include "../inc/evolver.h"
#include "../inc/field.h"
#include "../inc/term.h"

#ifdef WITHCUDA
#include <cuda.h>
#include <cuda_runtime.h>
#endif

#define NX 400
#define NY 400

void set_to_zero(float2 *, int, int);
__global__ void set_to_zero_k(float2*, int, int);

int main(int argc, char **argv)
{
    evolver system(1, NX, NY, 1.0f, 1.0f, 1.0f, 2);

    system.createField("phi", true);        // 0
    float D = 1.0f;

    system.fields[0]->isNoisy = true;
    system.fields[0]->noiseType = GaussianWhite;
    system.fields[0]->noise_amplitude = {D,0, 0, 0,0};

    cudaMemcpy(system.fields[0]->real_array_d, system.fields[0]->real_array, NX*NY*sizeof(float2), cudaMemcpyHostToDevice);
    cudaMemcpy(system.fields[0]->comp_array_d, system.fields[0]->comp_array, NX*NY*sizeof(float2), cudaMemcpyHostToDevice);

    system.fields[0]->toComp();

    for (int i = 0; i < system.fields.size(); i++)
    {
        system.fields[i]->prepareDevice();
        system.fields[i]->precalculateImplicit(system.dt);
    }
    system.fields[0]->outputToFile = true;

    int steps = 10000;
    int freq = 100;
    int check = steps/100;
    if (check < 1) check = 1;
    
    system.printInformation();

    for (int i = 0; i < steps; i++)
    {
        system.advanceTime();
        // do stuff with noise
        // apply filters here to cuda pointer:
        // system.fields[0]->comp_array_d
        // run system.fields[0]->toReal() to transform to real space
        // set phi to 0
        if (i%freq==0)
        {
            set_to_zero(system.fields[0]->real_array_d,NX,NY);
            system.fields[0]->toComp();
        }
        // output will always happen after setting to 0
        if (i % check == 0)
        {
            std::cout << "Progress: " << i/check << "%\r";
            std::cout.flush();
        }
    }

    return 0;
}


void set_to_zero(float2 *real_array, int sx, int sy)
{
    dim3 TPB(32,32);
    dim3 blocks(sx/32,sy/32);

    set_to_zero_k<<<blocks, TPB>>>(real_array, sx, sy);
}

__global__ void set_to_zero_k(float2 *real_array, int sx, int sy)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int j = blockIdx.y * blockDim.y + threadIdx.y;
    int index = j*sx + i;

    if (index < sx*sy)
    {
        real_array[index].x = 0.0f;
    }
}
