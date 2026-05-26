#ifndef __RKMUXER_H__
#define __RKMUXER_H__
#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdarg.h>

typedef void (*RKMUXER_LOG_FN)(const char *msg, va_list list);

#define RKMUXER_TRACE(level, fmt, ...)           \
      do {                                          \
          rkmuxer_log(level, fmt, __FUNCTION__,       \
                  __LINE__, ##__VA_ARGS__);         \
      } while (0)

#define RKMUXER_LOG(level, fmt, ...)  RKMUXER_TRACE(level, fmt, ##__VA_ARGS__)

void rkmuxer_log(int level, const char *fmt, const char *fname, const int row, ...);

typedef struct {
	unsigned int width;
	unsigned int height;
	unsigned int vir_width;
	unsigned int vir_height;
	unsigned int data_size;
	unsigned char *data;
} ThumbParam;

typedef struct StVideoParam {
	char format[24]; // NV12
	char codec[24];  // H.264, H.265
	int width;
	int height;
	int bit_rate;
	int profile; // h264 profile
	int level;   // h264 level
	int frame_rate_den;
	int frame_rate_num;
	int qp_min;
	int qp_max;
	int vir_width;
	int vir_height;
	int frag_keyframe;
	ThumbParam thumb;
} VideoParam;

typedef struct StAudioParam {
	char format[24]; // S16,S32
	char codec[24];  // MP2
	int channels;
	int sample_rate;
	int frame_size;
} AudioParam;

int rkmuxer_init(int id, char *format, const char *file_path, VideoParam *video_param,
                 AudioParam *audio_param);
int rkmuxer_deinit(int id);
int rkmuxer_write_video_frame(int id, unsigned char *buffer, unsigned int buffer_size,
                              int64_t present_time, int key_frame);
int rkmuxer_write_audio_frame(int id, unsigned char *buffer, unsigned int buffer_size,
                              int64_t present_time);

long long int rkmuxer_get_thumb_pos(int id);

void rkmuxer_set_log_callback(RKMUXER_LOG_FN log_fn);

#ifdef __cplusplus
}
#endif
#endif
