#ifndef __LIBRKEISAPI_H__
#define __LIBRKEISAPI_H__

#ifdef __cplusplus
extern "C" {
#endif

/**
	* Used to define the function API.
	* Can be switched by rewriting when you create a DLL in Windows.
*/
#if defined(ROCKCHIP_DLL) && defined(_WIN32)
#define ROCKCHIP_API(type) __declspec(dllexport) extern type
#else
#define ROCKCHIP_API(type) extern type
#endif

#ifdef WIN32
#define LABEL_EXPOSURE
#define LABEL_SECRET
#else
#define LABEL_EXPOSURE      __attribute__ ((visibility("default")))  
#define LABEL_SECRET        __attribute__ ((visibility("hidden")))  
#endif  

/* Error code */
#define ROCKCHIP_OK                   ((int)0x00000000)  /**< Successful */
#define ROCKCHIP_INPROGRESS           ((int)0x00010000)  /**< Now in progress */
#define ROCKCHIP_CANCELED             ((int)0x00020000)  /**< Canceled */
#define ROCKCHIP_SUSPENDED            ((int)0x00080000)  /**< Suspended */

#define ROCKCHIP_ERROR_GENERAL_ERROR  ((int)0x80000000)  /**< General error */
#define ROCKCHIP_ERROR_PARAM          ((int)0x80000001)  /**< Invalid argument */
#define ROCKCHIP_ERROR_STATE          ((int)0x80000002)  /**< Invalid internal state or function call order */
#define ROCKCHIP_ERROR_MALLOC         ((int)0x80000004)  /**< Memory allocation error */
#define ROCKCHIP_ERROR_IO             ((int)0x80000008)  /**< Input/output error */
#define ROCKCHIP_ERROR_UNSUPPORTED    ((int)0x80000010)  /**< Unsupported function */
#define ROCKCHIP_ERROR_NOTFOUND       ((int)0x80000020)  /**< Is not found to be searched */
#define ROCKCHIP_ERROR_INTERNAL       ((int)0x80000040)  /**< Internal error */
#define ROCKCHIP_ERROR_TIMEDOUT       ((int)0x80000080)  /**< Timed out */
#define ROCKCHIP_ERROR_UNKNOWN        ((int)0xC0000000)  /**< Error other than the above */


#define MAX_SENSOR_DATA_NUM 1024
#define MAX_X_GRID_SIZE 80
#define MAX_Y_GRID_SIZE 60
#define MAX_GRID_NUM (MAX_X_GRID_SIZE*MAX_Y_GRID_SIZE)


typedef enum {
	RK_EIS_TYPE_MOVIE_STABILIZE,  /**< movie stabilize type */
	RK_EIS_TYPE_MOTION_GRID,      /**< calculate motion grid */
	RK_EIS_TYPE_NUM,
} RK_EIS_type_t;

typedef enum {
	RK_EIS_PROCESS_TYPE_GPU, /**< Use GPU for render */
	RK_EIS_PROCESS_TYPE_CPU, /**< Use CPU only for render or calc motion detect */
	RK_EIS_PROCESS_TYPE_NUM,
} RK_EIS_process_type_t;

typedef enum {
	RK_EIS_PIXEL_FMT_RASTER_YUV420SP,   /**< RASTER: YUV420SP */
	RK_EIS_PIXEL_FMT_TILE4X4_YUV420,    /**< TILE4X4: YUV420 */
	RK_EIS_PIXEL_FMT_FBCE_YUV420,       /**< FBCE: YUV420 */
	RK_EIS_PIXEL_FMT_NUM,
} RK_EIS_format_type_t;

typedef enum {
	RK_EIS_MOTION_DETECT_MODE_SOFT,        /**< use image for motion detect*/
	RK_EIS_MOTION_DETECT_MODE_GYROSCOPE,   /**< use sensor data only */
	RK_EIS_MOTION_DETECT_MODE_HYBRID,      /**< use sensor data and image for motion detect */
	RK_EIS_MOTION_DETECT_MODE_SMOOTH_ZOOM, /**< smooth zoom stab mode */
	RK_EIS_MOTION_DETECT_MODE_NUM,
} RK_EIS_motion_detect_mode_t;

typedef enum {
	RK_EIS_OIS_TYPE_NONE,         /**< without OIS module*/
	RK_EIS_OIS_TYPE_LENS_SHIFT,   /**< lens shift type */
	RK_EIS_OIS_TYPE_MODULE_TILT,  /**< sensor OIS type */
	RK_EIS_OIS_TYPE_NUM,
} RK_EIS_ois_mode_t;

/*
 * @enum    RK_EIS_sensor_axes_order_t 
 * @brief   Specify the sensor axes order
 */
typedef enum {
    RK_EIS_SENSOR_AXES_ORDER_XYZ = 0x00, /**< X-Y-Z (Default) */
    RK_EIS_SENSOR_AXES_ORDER_XZY = 0x10, /**< X-Z-Y */
    RK_EIS_SENSOR_AXES_ORDER_YXZ = 0x20, /**< Y-X-Z */
    RK_EIS_SENSOR_AXES_ORDER_YZX = 0x30, /**< Y-Z-X */
    RK_EIS_SENSOR_AXES_ORDER_ZXY = 0x40, /**< Z-X-Y */
    RK_EIS_SENSOR_AXES_ORDER_ZYX = 0x50, /**< Z-Y-X */
} RK_EIS_sensor_axes_order_t;

/*
 * @enum    RK_EIS_sensor_axes_inverse_type_t 
 * @brief   Specify that the sensor axis is opposite to the image axis
 * @note    Inverse types can be expressed by bit operation
 */
typedef enum {
    RK_EIS_SENSOR_AXES_INVERSE_X = 1 << 2, /**< Sensor x-axis is opposite to the image x-axis. */
    RK_EIS_SENSOR_AXES_INVERSE_Y = 1 << 1, /**< Sensor y-axis is opposite to the image y-axis. */
    RK_EIS_SENSOR_AXES_INVERSE_Z = 1,      /**< Sensor z-axis is opposite to the image z-axis. */
} RK_EIS_sensor_axes_inverse_type_t;

typedef enum {
    RK_EIS_SENSOR_TYPE_GYRO,
    RK_EIS_SENSOR_TYPE_ACCEL,
    RK_EIS_SENSOR_TYPE_HALL,
} RK_EIS_sensor_type_t;


/** @struct rockchip_ImageYuvPlanar
*  @brief  Struct of Yuv Planar format.
*/
typedef struct {
	void * y;               /**< Head pointer of the Y image */
	void * u;               /**< Head pointer of the U image */
	void * v;               /**< Head pointer of the V image */
} rockchip_ImageYuvPlanar;

/** @struct rockchip_ImageYuvSemiPlanar
*  @brief  Struct of Yuv SemiPlanar format.
*/
typedef struct {
	void * y;               /**< Head pointer of the Y image */
	void * uv;              /**< Head pointer of the UV image */
} rockchip_ImageYuvSemiPlanar;



/** @struct rockchip_ImageYuvPlanarPitch
*  @brief  Pitch value of Yuv Planar format.
*/
typedef struct {
	int y;  /**< Y data. Number of bytes from head of line to the head of next line */
	int u;  /**< U data. Number of bytes from head of line to the head of next line */
	int v;  /**< V data. Number of bytes from head of line to the head of next line */
} rockchip_ImageYuvPlanarPitch;

/** @struct rockchip_ImageYuvSemiPlanarPitch
*  @brief  Pitch value of Yuv SemiPlanar format.
*/
typedef struct {
	int y;  /**< Y data. Number of bytes from head of line to the head of next line */
	int uv; /**< UV data. Number of bytes from head of line to the head of next line */
} rockchip_ImageYuvSemiPlanarPitch;

/** @struct rockchip_ImageDataEx
*  @brief  Image Data.
*/
typedef struct {
	int width;                                          /**< Width */
	int height;                                         /**< Height */
    int fd;                                             /**< file descriptor */
	union {
		void *p;                                        /**< Head pointer of the image data */
		rockchip_ImageYuvPlanar planar;                 /**< Planar struct */
		rockchip_ImageYuvSemiPlanar semi_planar;        /**< Semiplanar struct */
	} dat;                                              /**< image data pointer */
	union {
		int p;                                          /**< Number of bytes from head of line to the head of next line */
		rockchip_ImageYuvPlanarPitch planar;            /**< Planar pitch struct */
		rockchip_ImageYuvSemiPlanarPitch semi_planar;   /**< Semiplanar pitch struct */
	} pitch;                                            /**< image pitch union */
    unsigned long long phy_addr;                        /**< physical address */
	int size;
} rockchip_ImageDataEx;


/* pointer to engine */
typedef struct {
	void* p;
} RK_EIS;

typedef struct _RK_EIS_ldc_tag
{
	double k1;
	double k2;
	double p1;
	double p2;
	double k3;
	double xi;							/**< CMei camera Xi */
} RK_EIS_ldc;

typedef struct _RK_EIS_metadata_tag
{
	int iso_speed;      /**< iso speed */
	long long exp_time; /**< exposure time (ns) */
	long long timestamp;/**< image timestamp */
	long long rs_skew;  /**< rolling shutter skew */
	long long again;	/**< analog gain */
	long long dgain;	/**< digital gain */
	long long ispgain;	/**< isp gain */
	double iso;			/**< iso */
	double zoom_ratio;  /**< zoom ratio */
} RK_EIS_metadata;

typedef struct _RK_EIS_ctx_tag
{
	int x_grid_num;             /**< number of horizontal grid points*/
	int y_grid_num;             /**< number of vertical grid points*/
	float x_grid[MAX_GRID_NUM]; /**< horizontal grid coordinate for result images */
	float y_grid[MAX_GRID_NUM]; /**< vertical grid coordinate for result images */
} RK_EIS_ctx;

typedef struct _RK_EIS_buffer_tag
{
	int width;                              /**< image width in true active pixels */
	int height;                             /**< image height in true active pixels */
	int format;                             /**< image format @enum RK_EIS_format_type_t */
    rockchip_ImageDataEx buffer;            /**< image buffer */
	long long timestamp;                    /**< image timestamp */
	RK_EIS_metadata metadata;               /**< image meta data */
	int buffer_idx;                         /**< output buffer index */
	void* user_data;                        /**< user data about this object */
} RK_EIS_buffer;

typedef struct _RK_sensor_data_tag
{
	double x_data[MAX_SENSOR_DATA_NUM]; /**< angular velocity around the x-axis or acceleration along the x-axis. */
	double y_data[MAX_SENSOR_DATA_NUM]; /**< angular velocity around the y-axis or acceleration along the y-axis. */
	double z_data[MAX_SENSOR_DATA_NUM]; /**< angular velocity around the z-axis or acceleration along the z-axis. */
	long long timestamp[MAX_SENSOR_DATA_NUM]; /**< sensor data timestamp */
	int num; /**< sensor data num */
} RK_sensor_data;

typedef struct _RK_sensor_temp_data_tag
{
	double temp[MAX_SENSOR_DATA_NUM];
	long long timestamp[MAX_SENSOR_DATA_NUM]; /**< sensor data timestamp */
	int num;
}RK_sensor_temp_data;

typedef struct _RK_hall_data_tag
{
	double x_shift[MAX_SENSOR_DATA_NUM]; /**< shift along x-axis or shift around x-axis */
	double y_shift[MAX_SENSOR_DATA_NUM]; /**< shift along y-axis or shift around y-axis */
	long long timestamp[MAX_SENSOR_DATA_NUM]; /**< hall data timestmp */
	int num; /**< hall data num */
} RK_hall_data;

typedef struct _RK_follow_mode_params_tag
{
	double th1;
	double th2;
	double th3;
}RK_follow_mode_params;

typedef struct _RK_EIS_initParams_tag
{
    int still_crop;     /**< 0: use EIS algorithm; 1: not use EIS algorithm, but still crop fov and scale the output image to input size; */
	int src_type;        /**< function input type @RK_EIS_type_t */
	int dst_type;        /**< function output type @RK_EIS_type_t */
	int src_width;      /**< input image width in true active pixels */
	int src_height;     /**< input image height in true active pixels */
	int dst_width;		/**< output image width in true active pixels */
	int dst_height;		/**< output image width in true active pixels */
	int src_stride;     /**< input image width in extra invalid pixels */
	int src_height_stride;     /**< input image height in extra invalid pixels */
	int src_format;     /**< input image format (0 = raster; 1 = tile4x4) */
	int dst_stride;     /**< output image width in extra invalid pixels */
	int dst_height_stride;     /**< output image height in extra invalid pixels */
	int dst_format;     /**< output image format (0 = raster; 1 = tile4x4; 2 = FBCE) */
	int clip_width;     /**< output clipping width */
	int clip_height;    /**< output clipping height */
	int auto_scaling;   /**< output image will be upscale */
	int delay_num;      /**< delay frame number.Range [0,30] */
	int ois_mode;       /**< device OIS type, @enum RK_EIS_ois_mode_t */
	int dvs_mode;		/**< dvs algorithm type */
	int horizon_mode;	/**< horizon dvs algorithm type */
	int use_async;      /**< 1: perform processing asynchronously, 0: sync processing */
	double view_angle;  /**< input image HORIZONTAL view angle */
	double frame_rate;  /**< input video frame rate. Default 30.0 */
	int sensor_axes_type;/**< sensor axes type, refer to RK_EIS_sensor_axes_order_t and RK_EIS_sensor_axes_inverse_type_t */
	int motion_detect_mode;/**< Refer to @enum RK_EIS_motion_detect_mode_t */
	int num_cores;      /**< number of cores will be used */
	int affinity_mask;  /**< affinity mask setting */
	double imu_rate;	/**< input imu ODR.*/
    int remap_hw;       /**< remap hardware: 0=GPU; 1=FEC */
	int x_grid_step;	/**< step of horizontal grid */
	int y_grid_step;	/**< step of vertical grid */
	RK_follow_mode_params follow_mode_params;	/**< follow mode params */
	char opencl_lib_path[128];  /**< path of opencl library */
	char opencl_program_path[128]; /**< cached opencl program file */
	char reserved[256];	/**< reserved path */
} RK_EIS_initParams;

typedef struct _RK_EIS_runtimeParams_tag
{
	/* the frame rate of the input video. */
	double frame_rate;

	/* zoom ratio */
	double zoom_ratio;

	/* zoom threshold for no stabilze */
	double bypass_zoom_thd;

	/* fix level: Range [0, 7], Default 4
		* Higher fix level results in more stabilized results;
		* However, its response to pan or tilt will be worse. */
	int fix_level;

	/* moving subject level: Range [0, 7], Default 2
		* The larger the value, it is more difficult to be determined that
		* there is a moving subject. */
	int moving_subject_thd;

	/* no move subject level: Range [0, 7] Default 1
		* Threshold for no movement condition.
		* The larger the value, the easier it is to be determined that
		* the screen is still and actual hand jitter blurs are less corrected. */
	int no_movement_thd;
} RK_EIS_rtParams;

typedef struct _RK_EIS_estimation_tag
{
	double view_angle;                  /**< HORIZONTAL view angel of input image */
	double src_focal_length_x;          /**< focus length of x direction */
	double src_focal_length_y;          /**< focus length of x direction */
	double src_center_x;                /**< x coordinate of len's center */
	double src_center_y;                /**< y coordinate of len's center */
	double dst_focal_length_x;          /**< focus length of x direction */
	double dst_focal_length_y;          /**< focus length of x direction */
	double dst_center_x;                /**< x coordinate of len's center */
	double dst_center_y;                /**< y coordinate of len's center */
	double f_len_unit;                  /**< focus length uint */
	int force_use_json_rs;				/**< whether force use the rs time in the json file. 1 = use; 0 = not use */
	long long rs_skew;                  /**< rolling shutter skew of input */
	int start_of_scanline;              /**< 1: image timestamp generated before first scanline exposure; 0: generated after last scanline exposured */
	long long image_timestamp_offset;   /**< image timestamp offset value */
	long long gyro_timestamp_offset;    /**< gyro timestamp offset value */
	long long hall_timestamp_offset;    /**< hall timestamp offset value */
	RK_EIS_ldc src_ldc;                 /**< lens distortion coeff */
	RK_EIS_ldc dst_ldc;                 /**< lens distortion coeff */
    double  gyro_bias_x;				/**< bias of gyro x */
    double  gyro_bias_y;				/**< bias of gyro y */
    double  gyro_bias_z;				/**< bias of gyro z */
    double  acce_bias_x;				/**< bias of accel x */
    double  acce_bias_y;				/**< bias of accel y */
    double  acce_bias_z;				/**< bias of accel z */
} RK_EIS_estimation;


typedef struct _RK_EIS_callback_handler {
	/*
		* @brief Result callback func for asynchronously processing.
		* @param pSrcBuffer[in]  Point to input RK_EIS_buffer struct
		* @param pDstBuffer[in]  Point to output RK_EIS_buffer struct
		* @param ret[in]	   return status
		* @param userData[in] The user_data object passed to RK_EIS_initialize.
		*/
	void(*result_cb) (RK_EIS_buffer* pSrcBuffer, RK_EIS_buffer* pDstBuffer, int ret, void* userData);

    /*
        * @brief get output buffer callback func for asynchronously processing.
        * @param pDstBuffer[in/out]  Point to output RK_EIS_buffer struct
        * @return status
        */
    int(*get_output_buffer) (RK_EIS_buffer* pDstBuffer, void* userData);

	/*
		* @brief Callback func to obtain sensor data. This function should be
		*          implemented by the caller in hardGyro or hybrid motion detect mode.
		*          If unnecessary, set as NULL.
		* @param start_time[in]    Minmum timestamp of sensor data needed (nanoseconds)
		* @param end_time[in]      Maximum timestamp of sensor data needed (nanoseconds)
		* @param gyro_data[in/out] Point to Gyroscope data
		* @param acc_data[in/out]  Point to Accelerometer data
		* @param temp_data[in/out] Point to temperatrue data
		* @param hall_data[in/out] Point to Hall sensor data
		* @param user_data[in]     The user_data object passed to RK_EIS_initialize
        * @return status
		*/
    int(*acquire_sensor_data) (long long start_time, long long end_time,
		RK_sensor_data* gyro_data, RK_sensor_data* acc_data, RK_sensor_temp_data* temp_data,
		RK_hall_data* hall_data, void* user_data);
} RK_EIS_callback_handler;

typedef struct _RK_EIS_callback_userdata_tag {
    void* result_cb_userdata;
    void* get_output_buffer_userdata;
    void* acquire_sensor_data_userdata;
} RK_EIS_callback_userdata;


typedef struct _RK_EIS_initConfig_tag {
    char cfgJsonFile[1024];
    RK_EIS_callback_handler cbHandler;
    RK_EIS_callback_userdata cbUserdata;
    char reserved[256];
} RK_EIS_initConfig;


typedef struct _RK_imuData_tag {
    double *pGyroX;
    double *pGyroY;
    double *pGyroZ;
    double *pAcceX;
    double *pAcceY;
    double *pAcceZ;
    double *pTemp;
    long long *pTimestamp;
    int num;
} RK_imuData;

typedef struct _RK_hallData_tag {
    double *pShiftX; /**< shift along x-axis or shift around x-axis */
    double *pShiftY; /**< shift along y-axis or shift around y-axis */
    long long *pTimestamp; /**< hall data timestmp */
    int num; /**< hall data num */
} RK_hallData;

typedef struct _RK_EIS_sensorData_tag {
    RK_imuData imuData;
    RK_hallData hallData;
} RK_EIS_sensorData;



/**
* Prepare RK_EIS engine environment.
* @param[in,out] engine Engine instance pointer
* @return Error code
**/
LABEL_EXPOSURE ROCKCHIP_API(int) RK_EIS_prepare(RK_EIS* const engine);

/**
* Initialize RK_EIS engine.
* @param[in,out] engine Engine instance pointer
* @return Error code
**/
LABEL_EXPOSURE ROCKCHIP_API(int) RK_EIS_init(RK_EIS* const engine, RK_EIS_initConfig *pInitCfg);

/**
* @brief
* Start RK_EIS engine
* @param[in,out] engine Engine instance pointer
* @return Error code
**/
LABEL_EXPOSURE ROCKCHIP_API(int) RK_EIS_start(RK_EIS* const engine);

/**
* @brief
* Feed the current frame data to RK_EIS.
* Basically, this function requires the data of previous frames, in addition to the current one.
* And the engine expect the caller to stock these previous frames, using the ring buffer technique.
* In Async mode, engine will notify client by result_cb() after a frame was processed.
* In Sync mode, output and result context will maintain in current thread.
*
* @param[in,out] engine Engine instance pointer
* @param[in,out] input The current frame data
* @return Error codes.
*/
LABEL_EXPOSURE ROCKCHIP_API(int) RK_EIS_process_async(RK_EIS* const engine, RK_EIS_buffer *input);

/**
* @brief
* Finalizes RK_EIS.
* @param[in,out] engine Engine instance pointer
* @return Error Code
*/
LABEL_EXPOSURE ROCKCHIP_API(int) RK_EIS_finalize(RK_EIS* const engine);

/**
* @brief
* Destroy RK_EIS engine environment.
* @param[in,out] engine Engine instance pointer
* @return Error Code
*/
LABEL_EXPOSURE ROCKCHIP_API(int) RK_EIS_destroy(RK_EIS* const engine);

/**
* @brief
* Push the sensor data into RK_EIS.
* @param[in,out] engine Engine instance pointer
* @param[in] pSensorData Sensor data
* @return Error Code
*/
LABEL_EXPOSURE ROCKCHIP_API(int) RK_EIS_pushSensorData(RK_EIS* const engine, RK_EIS_sensorData *pSensorData);

/**
* @brief
* Get the string indicating version of RK_EIS.
* @return Library Version
*/
LABEL_EXPOSURE ROCKCHIP_API(const char*) RK_EIS_getVersion(void);




#ifdef __cplusplus
} /* extern "C" { */
#endif
#endif //__LIBRKEISAPI_H__
