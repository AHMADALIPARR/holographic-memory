# CUDA and GPU Notes

This directory is reserved for optional GPU acceleration experiments.

## Purpose

The core CPU implementation is complete and tested. GPU acceleration may be added later for direct or FFT-based convolution kernels.

## Current status

- CPU direct convolution implemented
- CPU FFT path implemented
- CUDA/PTX acceleration not required for the base system
- GPU path remains optional and should only be added when performance data justify it

## Notes

A CUDA path should be treated as an optimization for large vectors and high throughput, not as a replacement for the correctness of the CPU implementation.
