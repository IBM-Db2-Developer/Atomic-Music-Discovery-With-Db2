//
//  MaxFilter.metal
//  Swiftzam
//
//  Created by Tanmay Bakshi on 2021-06-26.
//

#include <metal_stdlib>
using namespace metal;

kernel void maxFilter(device char *output, device const float *input, device const int *params, uint index [[thread_position_in_grid]]) {
    int width = params[0];
    int height = params[1];
    int threshold = params[2];
    
    int x = index % width;
    int y = index / width;
    
    if (x >= width || y >= height) return;
    
    float maxValue = input[index];
    for (int yOffset = 0; yOffset < 41; yOffset++) {
        int skip = abs(20 - yOffset);
        for (int xOffset = skip; xOffset < (41 - skip); xOffset++) {
            int newX = x + (20 - xOffset);
            int newY = y + (20 - yOffset);
            if (newX < 0 || newY < 0) continue;
            if (newX >= width || newY >= height) continue;
            float value = input[newX + newY * width];
            if (value > maxValue) maxValue = value;
        }
    }
    
    if (input[index] == maxValue && maxValue >= (float) threshold)
        output[index] = 1;
    else
        output[index] = 0;
}

//kernel void nearestNeighbours(device int *timeNN, device int *freqNN, device const int *time, device const int *freq, device const int *params, uint index [[thread_position_in_grid]]) {
//    int stars = params[0];
//    int totalNeighbours = params[1];
//
//}
