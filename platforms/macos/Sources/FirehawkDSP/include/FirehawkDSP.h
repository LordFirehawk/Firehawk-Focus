#ifndef FIREHAWK_DSP_H
#define FIREHAWK_DSP_H
#include <stdint.h>
typedef struct FHDSP FHDSP;
FHDSP *fh_create(double sampleRate, int layers);
void fh_destroy(FHDSP *dsp);
typedef struct FHBuffer FHBuffer;
// Create/copy off the render and UI threads. Install takes ownership on the
// single control thread; retired buffers are collected only outside render.
FHBuffer *fh_buffer_create(const float *left, const float *right, uint32_t frames);
void fh_buffer_destroy(FHBuffer *buffer);
void fh_install_buffer(FHDSP *dsp, int layer, FHBuffer *buffer);
void fh_collect(FHDSP *dsp);
// Convenience copy for offline callers. Never call from render.
int fh_set_buffer(FHDSP *dsp, int layer, const float *left, const float *right, uint32_t frames);
void fh_layer(FHDSP *dsp, int layer, int noise, double gain, double depth, double period, double rampSeconds);
void fh_master(FHDSP *dsp, double gain, double seconds);
void fh_tone(FHDSP *dsp, int mode, double carrier, double beat, double depth, double gain, double seconds);
void fh_render(FHDSP *dsp, float *left, float *right, uint32_t frames);
double fh_level(FHDSP *dsp, int layer);
uint64_t fh_memory(FHDSP *dsp);
#endif
