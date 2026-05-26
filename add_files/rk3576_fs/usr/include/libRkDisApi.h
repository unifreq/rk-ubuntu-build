#ifndef __LIBRKDISAPI_H__
#define __LIBRKDISAPI_H__

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
	RK_DIS_PIXEL_FMT_RASTER_YUV420SP,   /**< RASTER: YUV420SP */
	RK_DIS_PIXEL_FMT_TILE4X4_YUV420,    /**< TILE4X4: YUV420 */
	RK_DIS_PIXEL_FMT_FBCE_YUV420,       /**< FBCE: YUV420 */
	RK_DIS_PIXEL_FMT_NUM,
} RK_DIS_format_type_t;

typedef struct {
	void * y;               /**< Head pointer of the Y image */
	void * u;               /**< Head pointer of the U image */
	void * v;               /**< Head pointer of the V image */
} RK_DIS_ImageYuvPlanar;

typedef struct {
	void * y;               /**< Head pointer of the Y image */
	void * uv;              /**< Head pointer of the UV image */
} RK_DIS_ImageYuvSemiPlanar;

typedef struct {
	int y;  /**< Y data. Number of bytes from head of line to the head of next line */
	int u;  /**< U data. Number of bytes from head of line to the head of next line */
	int v;  /**< V data. Number of bytes from head of line to the head of next line */
} RK_DIS_ImageYuvPlanarPitch;

typedef struct {
	int y;  /**< Y data. Number of bytes from head of line to the head of next line */
	int uv; /**< UV data. Number of bytes from head of line to the head of next line */
} RK_DIS_ImageYuvSemiPlanarPitch;

typedef struct {
	int width;                                        /**< Width */
	int height;                                       /**< Height */
	int fd;                                           /**< file descriptor */
	union {
		void *p;                                      /**< Head pointer of the image data */
		RK_DIS_ImageYuvPlanar planar;                 /**< Planar struct */
		RK_DIS_ImageYuvSemiPlanar semi_planar;        /**< Semiplanar struct */
	} dat;                                            /**< image data pointer */
	union {
		int p;                                        /**< Number of bytes from head of line to the head of next line */
		RK_DIS_ImageYuvPlanarPitch planar;            /**< Planar pitch struct */
		RK_DIS_ImageYuvSemiPlanarPitch semi_planar;   /**< Semiplanar pitch struct */
	} pitch;                                          /**< image pitch union */
	unsigned long long phy_addr;                      /**< physical address */
	int size;
} RK_DIS_ImageDataEx;

typedef struct {
	void* p;
} RK_DIS;

typedef struct _RK_DIS_metadata_tag
{
	int iso_speed;      /**< iso speed */
	long long exp_time; /**< exposure time (ns) */
	long long timestamp;/**< image timestamp */
	long long rs_skew;  /**< rolling shutter skew */
	long long again;    /**< analog gain */
	long long dgain;    /**< digital gain */
	long long ispgain;  /**< isp gain */
	double iso;         /**< iso */
	double zoom_ratio;  /**< zoom ratio */
} RK_DIS_metadata;

typedef struct _RK_DIS_buffer_tag
{
	int width;                              /**< image width in true active pixels */
	int height;                             /**< image height in true active pixels */
	int format;                             /**< image format @enum RK_DIS_format_type_t */
	RK_DIS_ImageDataEx buffer;              /**< image buffer */
	long long timestamp;                    /**< image timestamp */
	RK_DIS_metadata metadata;               /**< image meta data */
	int buffer_idx;                         /**< output buffer index */
	void* user_data;                        /**< user data about this object */
} RK_DIS_buffer;

typedef struct _RK_DIS_callback_handler {
	void(*result_cb) (RK_DIS_buffer* pSrcBuffer, RK_DIS_buffer* pDstBuffer, int ret, void* userData);
	int(*get_output_buffer) (RK_DIS_buffer* pDstBuffer, void* userData);
} RK_DIS_callback_handler;

typedef struct _RK_DIS_callback_userdata_tag {
	void* result_cb_userdata;
	void* get_output_buffer_userdata;
} RK_DIS_callback_userdata;

typedef struct _RK_DIS_initConfig_tag {
	char cfgJsonFile[1024];
	RK_DIS_callback_handler cbHandler;
	RK_DIS_callback_userdata cbUserdata;
	char reserved[256];
} RK_DIS_initConfig;

const char* RK_DIS_getVersion(void);

int RK_DIS_prepare(RK_DIS* const engine);

int RK_DIS_init(RK_DIS* const engine, RK_DIS_initConfig *pInitCfg);

int RK_DIS_start(RK_DIS* const engine);

int RK_DIS_process_async(RK_DIS* const engine, RK_DIS_buffer *input);

int RK_DIS_process_sync(RK_DIS* const engine, RK_DIS_buffer *input);

int RK_DIS_finalize(RK_DIS* const engine);

int RK_DIS_destroy(RK_DIS* const engine);

#ifdef __cplusplus
} /* extern "C" { */
#endif
#endif //__LIBRKDISAPI_H__
