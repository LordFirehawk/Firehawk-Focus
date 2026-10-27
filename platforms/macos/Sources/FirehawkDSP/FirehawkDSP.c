#include "FirehawkDSP.h"
#include <stdlib.h>
#include <stdatomic.h>
#include <math.h>
#define MAX_LAYERS 256
#define TAU 6.283185307179586
// Single control writer, single render reader. Parameters and immutable buffer
// pointers cross the thread boundary; render never owns reclamation.
_Static_assert(ATOMIC_POINTER_LOCK_FREE == 2 && ATOMIC_INT_LOCK_FREE == 2, "Render atomics must be lock-free");
_Static_assert(__atomic_always_lock_free(sizeof(double), 0), "Audio parameters must be lock-free");
typedef struct { _Atomic double target, seconds; double current, destination, step; uint64_t remaining; } Ramp;
typedef struct {
    Ramp gain; _Atomic double depth, period, level; _Atomic int noise;
    _Atomic(struct FHBuffer *) buffer; uint32_t pos, seed; double phase, pink[7], brown;
} Layer;
struct FHBuffer { float *l, *r; uint32_t count; struct FHBuffer *next; };
struct FHDSP { double rate; int count; Layer layers[MAX_LAYERS]; Ramp master, tone;
    _Atomic double carrier, beat, pulse; _Atomic int mode;
    double phaseL, phaseR, phasePulse, smoothCarrier, smoothBeat, smoothPulse, modes[3]; _Atomic uint64_t memory; _Atomic unsigned readers; struct FHBuffer *retired;
};
static void target(Ramp *r,double v,double seconds) { atomic_store(&r->seconds,seconds); atomic_store(&r->target,v); }
static double ramp(Ramp *r,double rate) {
    double t=atomic_load(&r->target);
    if(t!=r->destination) { r->destination=t; r->remaining=fmax(1,atomic_load(&r->seconds)*rate); r->step=(t-r->current)/r->remaining; }
    if(r->remaining) { r->current+=r->step; if(!--r->remaining) r->current=r->destination; }
    return r->current;
}
FHDSP *fh_create(double rate,int count) {
    if(rate<=0 || count<0 || count>MAX_LAYERS) return NULL;
    FHDSP *d=calloc(1,sizeof(FHDSP)); if(!d)return NULL; d->rate=rate; d->count=count;
    d->smoothCarrier=220; d->smoothBeat=10; atomic_store(&d->carrier,220); atomic_store(&d->beat,10);
    for(int i=0;i<count;i++){ d->layers[i].seed=1234567+i*7919; atomic_store(&d->layers[i].period,60); }
    return d;
}
FHBuffer *fh_buffer_create(const float *l,const float *r,uint32_t n) {
    if(!l||!r||!n)return NULL;
    FHBuffer *b=calloc(1,sizeof(*b)); if(!b)return NULL;
    b->l=malloc((size_t)n*sizeof(float)); b->r=malloc((size_t)n*sizeof(float));
    if(!b->l||!b->r){fh_buffer_destroy(b);return NULL;}
    for(uint32_t j=0;j<n;j++){b->l[j]=l[j];b->r[j]=r[j];} b->count=n; return b;
}
void fh_buffer_destroy(FHBuffer *b){if(b){free(b->l);free(b->r);free(b);}}
// One control-thread writer. Exchange precedes the zero-reader check in the
// sequentially consistent order. Any reader of the old pointer is therefore
// counted until it finishes; later readers can only acquire the new pointer.
void fh_collect(FHDSP *d){
    if(atomic_load(&d->readers)!=0)return;
    FHBuffer *b=d->retired; d->retired=NULL;
    while(b){FHBuffer *next=b->next;atomic_fetch_sub(&d->memory,(uint64_t)b->count*8);fh_buffer_destroy(b);b=next;}
}
void fh_install_buffer(FHDSP *d,int i,FHBuffer *b){
    if(!d||i<0||i>=d->count){fh_buffer_destroy(b);return;}
    if(b)atomic_fetch_add(&d->memory,(uint64_t)b->count*8);
    FHBuffer *old=atomic_exchange(&d->layers[i].buffer,b);
    if(old){old->next=d->retired;d->retired=old;}
    fh_collect(d);
}
void fh_destroy(FHDSP *d) {
    if(!d)return;
    // Caller has stopped the audio graph and joined all render callbacks.
    for(int i=0;i<d->count;i++)fh_buffer_destroy(atomic_load(&d->layers[i].buffer));
    fh_collect(d);free(d);
}
int fh_set_buffer(FHDSP *d,int i,const float *l,const float *r,uint32_t n){
    if(!d||i<0||i>=d->count||atomic_load(&d->layers[i].buffer))return 0;
    FHBuffer *b=fh_buffer_create(l,r,n); if(!b)return 0;
    fh_install_buffer(d,i,b);return 1;
}
void fh_layer(FHDSP *d,int i,int noise,double gain,double depth,double period,double seconds){
    if(!d||i<0||i>=d->count)return; Layer *s=&d->layers[i];atomic_store(&s->noise,noise);atomic_store(&s->depth,depth);atomic_store(&s->period,fmax(10,period));target(&s->gain,gain,seconds);
}
void fh_master(FHDSP *d,double gain,double seconds){target(&d->master,gain,seconds);}
void fh_tone(FHDSP *d,int mode,double carrier,double beat,double depth,double gain,double seconds){
    atomic_store(&d->mode,mode);atomic_store(&d->carrier,carrier);atomic_store(&d->beat,beat);atomic_store(&d->pulse,depth);target(&d->tone,gain,seconds);
}
static double noise(Layer *s,int type){
    uint32_t x=s->seed;x^=x<<13;x^=x>>17;x^=x<<5;s->seed=x;double w=(double)x/2147483648.0-1;
    if(type==1)return w*0.35;
    if(type==2){ double *b=s->pink;
        b[0]=.99886*b[0]+w*.0555179;b[1]=.99332*b[1]+w*.0750759;b[2]=.969*b[2]+w*.153852;
        b[3]=.8665*b[3]+w*.3104856;b[4]=.55*b[4]+w*.5329522;b[5]=-.7616*b[5]-w*.016898;
        double p=(b[0]+b[1]+b[2]+b[3]+b[4]+b[5]+b[6]+w*.5362)*.11;b[6]=w*.115926;return tanh(p)*.65;
    }
    s->brown=.995*s->brown+w*.035;return tanh(s->brown)*.8;
}
void fh_render(FHDSP *d,float *left,float *right,uint32_t frames){
    atomic_fetch_add(&d->readers,1);
    FHBuffer *buffers[MAX_LAYERS];
    for(int i=0;i<d->count;i++)buffers[i]=atomic_load(&d->layers[i].buffer);
    for(uint32_t f=0;f<frames;f++){
        double l=0,r=0;
        for(int i=0;i<d->count;i++){
            Layer *s=&d->layers[i];double g=ramp(&s->gain,d->rate);
            double osc=1-atomic_load(&s->depth)*(.5-.5*cos(s->phase));
            s->phase+=TAU/(atomic_load(&s->period)*d->rate);if(s->phase>=TAU)s->phase-=TAU;
            atomic_store(&s->level,g*osc); g*=osc;
            int type=atomic_load(&s->noise);
            if(type){ if(g>0){double n=noise(s,type);l+=n*g;r+=n*g;} }
            else if(buffers[i]){ FHBuffer *b=buffers[i]; if(s->pos>=b->count)s->pos=0;
                l+=b->l[s->pos]*g;r+=b->r[s->pos]*g;if(++s->pos==b->count)s->pos=0; }
        }
        double k=1-exp(-1/(.03*d->rate));
        d->smoothCarrier+=(atomic_load(&d->carrier)-d->smoothCarrier)*k;
        d->smoothBeat+=(atomic_load(&d->beat)-d->smoothBeat)*k;
        d->smoothPulse+=(atomic_load(&d->pulse)-d->smoothPulse)*k;
        double g=ramp(&d->tone,d->rate), a=sin(d->phaseL), b=sin(d->phaseR);
        int mode=atomic_load(&d->mode);
        for(int m=0;m<3;m++)d->modes[m]+=((mode==m?1.0:0.0)-d->modes[m])*k;
        double iso=sin(d->phaseL)*(1-d->smoothPulse*(.5-.5*cos(d->phasePulse)));
        l+=g*(d->modes[0]*a+d->modes[1]*(a+b)*.5+d->modes[2]*iso);
        r+=g*(d->modes[0]*b+d->modes[1]*(a+b)*.5+d->modes[2]*iso);
        d->phaseL+=TAU*(d->smoothCarrier-(mode==2?0:d->smoothBeat*.5))/d->rate;
        d->phaseR+=TAU*(d->smoothCarrier+d->smoothBeat*.5)/d->rate;
        d->phasePulse+=TAU*d->smoothBeat/d->rate;
        if(d->phaseL>=TAU)d->phaseL-=TAU;if(d->phaseR>=TAU)d->phaseR-=TAU;if(d->phasePulse>=TAU)d->phasePulse-=TAU;
        double master=ramp(&d->master,d->rate);
        left[f]=tanh(l*.5)*master;right[f]=tanh(r*.5)*master;
    }
    atomic_fetch_sub(&d->readers,1);
}
double fh_level(FHDSP *d,int i){return i>=0&&i<d->count?atomic_load(&d->layers[i].level):0;}
uint64_t fh_memory(FHDSP *d){return atomic_load(&d->memory)+sizeof(*d);}
