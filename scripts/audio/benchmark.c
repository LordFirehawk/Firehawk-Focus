// clang -O2 -I platforms/macos/Sources/FirehawkDSP/include scripts/audio/benchmark.c platforms/macos/Sources/FirehawkDSP/FirehawkDSP.c -o /tmp/firehawk-dsp-benchmark
// Offline worst-case: eight 60-second stereo buffers plus a tone, all gains and oscillation enabled.
#include "FirehawkDSP.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <sys/resource.h>
int main(void) {
    const int n=44100*60; FHDSP *d=fh_create(44100,8);
    float *pcm=malloc(n*sizeof(float));
    for(int i=0;i<n;i++)pcm[i]=.1*sin(i*.01);
    for(int i=0;i<8;i++){if(!fh_set_buffer(d,i,pcm,pcm,n))return 1;fh_layer(d,i,0,1,.5,60,.04);}
    free(pcm); fh_master(d,1,.3);fh_tone(d,0,220,10,.8,.3,.3);
    float l[512],r[512]; clock_t start=clock();
    for(int i=0;i<(int)(44100*60/512);i++)fh_render(d,l,r,512);
    double elapsed=(double)(clock()-start)/CLOCKS_PER_SEC;
    struct rusage usage;getrusage(RUSAGE_SELF,&usage);
    printf("DSP allocated %.2f MiB; peak RSS %.2f MiB; CPU %.3fs per 60s audio = %.2f%% of one core\n",fh_memory(d)/1048576.0,usage.ru_maxrss/1048576.0,elapsed,100*elapsed/60);
    fh_destroy(d);
}
