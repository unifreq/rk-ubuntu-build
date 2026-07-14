/*
 * awb_head2.h
 *
 *  Copyright (c) 2021 Rockchip Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#ifndef __AWB_HEADER2_H__
#define __AWB_HEADER2_H__
#if defined(ISP_HW_V39)
#include "isp/rk_aiq_stats_awb39.h"
#else //defined(ISP_HW_V33)
#include "isp/rk_aiq_stats_awb33.h"
#endif

#define CALD_AWB_LWR_NUM_MAX 8
#define CALID_AWB_CT_LUT_NUM 8
#define CALID_AWB_CT_GRID_NUM 11
#define CALID_AWB_MAX_ISO_LEVEL 13
#define CALD_AWB_LS_NUM_MAX 14
#define CALD_AWB_SGC_NUM_MAX 16
#define CALID_AWB_LGT_PREFGN_NUM_MAX 4
#define CALID_AWB_GNEXT_GN_NUM_MAX 7
#define CALID_AWB_GNEXT_RTO_NUM_MAX 7

#define CALD_AWB_EXCRANGE_NUM_MAX 7
#define CALD_AWB_LV_NUM_MAX 16
#define CALD_AWB_ILLUMINATION_NAME       ( 20U )
#define CALD_AWB_GRID_NUM_TOTAL_LITE 25
#define CALD_AWB_GRID_NUM_TOTAL 225
#define CALD_AWB_RGCT_GRID_NUM 9
#define CALD_AWB_BGCRI_GRID_NUM 11

#define AWB_SGC_CT_GRID_NUM 3
#define AWB_SGC_DIS_GRID_NUM 6
#define AWB_SGC_LV_GRID_NUM 8
#define AWB_SGC_GRAD_GRID_NUM 6
#define AWB_SGC_WPNUM_GRID_NUM 6
#define CALD_AWB_RGCT_GRID_NUM 9
#define CALD_AWB_BGCRI_GRID_NUM 11

typedef enum awb_ctrlDatSelt_e{
    awb_ctrlData_iso = 0,
    awb_ctrlData_lv = 1,
}awb_ctrlDatSelt_t;
typedef enum awb_GainAdjDatSelt_e{
    awb_GainAdjDatSelt_gain = 0,
    awb_GainAdjDatSelt_ct = 1,
}awb_GainAdjDatSelt_t;

typedef enum awb_sgc_mode_s{
    awb_sgcCall_initial = 0,
    awb_sgcCall_auto = 1,
    awb_sgcCall_always = 2
}awb_sgc_mode_e;

typedef enum wb_mwb_mode_e {
    mwb_mode_cct                  = 1,        /**< run manual white balance by cct*/
    mwb_mode_wbgain               = 2,        /**< run manual white balance by wbGain*/
    mwb_mode_scene                = 3,       /**< run manual white balance by scene selection*/
} wb_mwb_mode_t;

typedef enum wb_mwb_scene_e {
    mwb_scene_incandescent = 0,
    mwb_scene_fluorescent,
    mwb_scene_warm_fluorescent,
    mwb_scene_daylight,
    mwb_scene_cloudy_daylight,
    mwb_scene_twilight,
    mwb_scene_shade
} wb_mwb_scene_t;


typedef enum awb_ext_range_mode_s {
    awb_wpFiltOut_mode = 1,
    awb_wpExtraLs_mode = 3,
} awb_ext_range_mode_t;

typedef enum awb_doortype_e {
    awb_doorType_invalid = 0,
    awb_doorType_indoor = 1,
    awb_doorType_ambiguity = 2,
    awb_doorType_outdoor = 3,
} awb_doortype_t;

typedef enum awb_earlAct_mdoe_e {
    awb_earlActXyReg_auto_mode = 0,
    awb_earlActXyReg_fixed_mode,
} awb_earlAct_mdoe_t;

typedef enum awb_ganCalcMethod_s{
    awb_gan_calc_method_invalid=-1,
    awb_gan_calc_method_auto = 0,
    awb_gan_calc_method_zone_mean = 1,
    awb_gan_calc_method_wp_nor = 2,
    awb_gan_calc_method_wp_big = 3,
    awb_gan_calc_method_wp_ext = 4,
    awb_gan_calc_method_sgc = 5,
}awb_ganCalcMethod_e;

typedef struct awb_cct_s {
     /* M4_GENERIC_DESC(
        M4_ALIAS(cct),
        M4_TYPE(f32),
        M4_RANGE_EX(0,10000),
        M4_DEFAULT(5000),
        M4_RO(0),
        M4_ORDER(0),
        M4_DIGIT_EX(0),
        M4_NOTES(.\n
        Freq of use: high))  */
    float cct;
     /* M4_GENERIC_DESC(
        M4_ALIAS(ccri),
        M4_TYPE(f32),
        M4_RANGE_EX(-2,2),
        M4_DEFAULT(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_DIGIT_EX(3),
        M4_NOTES(.\n
        Freq of use: high))  */
    float ccri;
} awb_cct_t;
typedef struct wb_mwb_cfg_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(manual_wbgain),
        M4_TYPE(f32),
        M4_SIZE_EX(1,4),
        M4_RANGE_EX(0,8),
        M4_DEFAULT(1),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float manual_wbgain[4];//rggb
    /* M4_GENERIC_DESC(
        M4_ALIAS(scene_mode),
        M4_TYPE(enum),
        M4_ENUM_DEF(wb_mwb_scene_t),
        M4_DEFAULT(mwb_scene_daylight),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    wb_mwb_scene_t scene_mode;
     /* M4_GENERIC_DESC(
        M4_ALIAS(cct),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(TODO \n
        Freq of use: high))  */
    awb_cct_t cct;
} wb_mwb_cfg_t;

typedef struct wb_mwb_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(mode),
        M4_TYPE(enum),
        M4_ENUM_DEF(wb_mwb_mode_t),
        M4_DEFAULT(mwb_mode_wbgain),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    wb_mwb_mode_t mode;
     /* M4_GENERIC_DESC(
        M4_ALIAS(cfg),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(TODO \n
        Freq of use: high))  */
    wb_mwb_cfg_t cfg;
} wb_mwb_t;

typedef struct awb_xyWpDct_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(normal),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Parameters for detecting normal white points in XY space \n
        Freq of use: low))  */
    awbStats_xyRegion_t normal;
    /* M4_GENERIC_DESC(
        M4_ALIAS(big),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Parameters for big detecting white points in XY space \n
        Freq of use: low))  */
    awbStats_xyRegion_t big;
} awb_xyWpDct_t;

typedef struct awb_sgc_cBlk_s {
     /* M4_GENERIC_DESC(
        M4_ALIAS(index),
        M4_TYPE(u16),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(1,24),
        M4_DEFAULT(1),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: low))  */
    unsigned short index;
    /* M4_GENERIC_DESC(
        M4_ALIAS(meanC),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255),
        M4_DEFAULT(0),
        M4_DIGIT_EX(6),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: low))  */
    float meanC;
    /* M4_GENERIC_DESC(
        M4_ALIAS(meanH),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(-180,180),
        M4_DEFAULT("0"),
        M4_DIGIT_EX(6),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    float meanH;
    /* M4_GENERIC_DESC(
        M4_ALIAS(ct),
        M4_TYPE(f32),
        M4_SIZE_EX(1,3),
        M4_RANGE_EX(0,10000),
        M4_DEFAULT("[2000, 5000, 6500]"),
        M4_DIGIT_EX(0),
        M4_DYNAMIC(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    float ct[AWB_SGC_CT_GRID_NUM];
    /* M4_GENERIC_DESC(
        M4_ALIAS(dist_th),
        M4_TYPE(f32),
        M4_SIZE_EX(1,3),
        M4_RANGE_EX(0,100000),
        M4_DEFAULT("[900, 900, 900]"),
        M4_DIGIT_EX(0),
        M4_DYNAMIC(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    float dist_th[AWB_SGC_CT_GRID_NUM];
} awb_sgc_cBlk_t;


typedef struct awb_sgc_lgtSrc_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(name),
        M4_TYPE(string),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255),
        M4_DEFAULT("D50"),
        M4_DYNAMIC(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    char name[CALD_AWB_ILLUMINATION_NAME];
    /* M4_GENERIC_DESC(
        M4_ALIAS(rGain),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,8),
        M4_DEFAULT("1"),
        M4_DIGIT_EX(6),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    float rGain;
    /* M4_GENERIC_DESC(
        M4_ALIAS(bGain),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,8),
        M4_DEFAULT("1"),
        M4_DIGIT_EX(6),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    float bGain;
} awb_sgc_lgtSrc_t;

typedef struct awb_gainOffset_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(offset_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT("1"),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: high))  */
    bool offset_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(offset_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,4),
        M4_RANGE_EX(-8,8),
        M4_DEFAULT("[0, 0, 0, 0]"),
        M4_DIGIT_EX(4),
        M4_DYNAMIC(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: high))  */
    float offset_val[4];
} awb_gainOffset_t;

typedef struct awb_dampFactor_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(df_step),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT("0.05"),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: high))  */
    float df_step;
    /* M4_GENERIC_DESC(
        M4_ALIAS(df_min),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT("0.7"),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: high))  */
    float df_min;
    /* M4_GENERIC_DESC(
        M4_ALIAS(df_max),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT("0.9"),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: high))  */
    float df_max;
    /* M4_GENERIC_DESC(
        M4_ALIAS(lvIIR_size),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,128),
        M4_DEFAULT("4"),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    int lvIIR_size;
    /* M4_GENERIC_DESC(
        M4_ALIAS(lvVar_th),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,100),
        M4_DEFAULT("0.04"),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    float lvVar_th;
} awb_dampFactor_t;


typedef struct awb_remosaic_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(remosaic_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT("1"),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    bool remosaic_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(applyInvWbGain_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT("1"),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    bool applyInvWbGain_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(sensor_wbgain),
        M4_TYPE(f32),
        M4_SIZE_EX(1,4),
        M4_RANGE_EX(0,4),
        M4_DEFAULT("[1, 1, 1, 1]"),
        M4_DIGIT_EX(4),
        M4_DYNAMIC(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    float sensor_wbgain[4];
} awb_remosaic_t;

typedef struct awb_converge_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(converged_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,16),
        M4_DEFAULT(10),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(1),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    int converged_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT([0,0.5,2,4,16,32,64,256,1024,2048]),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float luma_val[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(unDampVar_th),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,8),
        M4_DEFAULT("0"),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    float  unDampVar_th[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(dampVar_th),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,8),
        M4_DEFAULT("0"),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    float  dampVar_th[CALD_AWB_LV_NUM_MAX];
} awb_converge_t;


typedef struct awb_gainCtrl_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(byPass),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT("0"),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: high))  */
    bool byPass;
    /* M4_GENERIC_DESC(
        M4_ALIAS(opMode),
        M4_TYPE(enum),
        M4_ENUM_DEF(rk_aiq_op_mode_t),
        M4_DEFAULT(RK_AIQ_OP_MODE_AUTO),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(The current operation mode.\n
        Freq of use: high))  */
    rk_aiq_op_mode_t opMode;
    /* M4_GENERIC_DESC(
        M4_ALIAS(manualPara),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    wb_mwb_t manualPara;
} awb_gainCtrl_t;


typedef struct awb_offset_data_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(offset_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,13),
        M4_DEFAULT(13),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(1),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: low))  */
    int offset_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(iso),
        M4_TYPE(u32),
        M4_SIZE_EX(1,13),
        M4_RANGE_EX(0,10000000),
        M4_DEFAULT([50, 100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200, 102400, 204800]),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(The iso array for dynamic params array\n
        Freq of use: low))  */
    float iso[CALID_AWB_MAX_ISO_LEVEL];
    /* M4_GENERIC_DESC(
        M4_ALIAS(r_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,13),
        M4_RANGE_EX(-4096,4095),
        M4_DEFAULT(0),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(The optical black correction of bayer R pixel in awb statics module.\n
        It is is recommended to be calibrated and generated\n
        Freq of use: low))  */
    float r_val[CALID_AWB_MAX_ISO_LEVEL];
    /* M4_GENERIC_DESC(
        M4_ALIAS(gr_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,13),
        M4_RANGE_EX(-4096,4095),
        M4_DEFAULT(0),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(The optical black correction of bayer Gr pixel in awb statics module.\n
        It is is recommended to be calibrated and generated\n
        Freq of use: low))  */
    float gr_val[CALID_AWB_MAX_ISO_LEVEL];
    /* M4_GENERIC_DESC(
        M4_ALIAS(gb_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,13),
        M4_RANGE_EX(-4096,4095),
        M4_DEFAULT(0),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(The optical black correction of bayer Gb pixel in awb statics module.\n
        It is is recommended to be calibrated and generated\n
        Freq of use: low))  */
    float gb_val[CALID_AWB_MAX_ISO_LEVEL];
    /* M4_GENERIC_DESC(
        M4_ALIAS(b_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,13),
        M4_RANGE_EX(-4096,4095),
        M4_DEFAULT(0),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(The optical black correction of bayer B pixel in awb statics module.\n
        It is is recommended to be calibrated and generated\n
        Freq of use: low))  */
    float b_val[CALID_AWB_MAX_ISO_LEVEL];
} awb_offset_data_t;

typedef struct awb_blc_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(enable),
        M4_TYPE(bool),
        M4_DEFAULT(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Whether to enable awb blc.\nFreq of use: high\n
        Freq of use: low))  */
    bool enable;
     /* M4_GENERIC_DESC(
        M4_ALIAS(offset),
        M4_TYPE(struct),
        M4_UI_MODULE(array_table_ui),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(The enable bit of blc in the awb statistics module\n
        Freq of use: low))  */
    awb_offset_data_t offset;
} awb_blc_t;

typedef struct awb_rgbySpace_cfg_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(cfg_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,16),
        M4_DEFAULT(10),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(1),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    int cfg_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT([0,0.5,2,4,16,32,64,256,1024,2048]),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float luma_val[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(maxR_thred),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255),
        M4_DEFAULT(230),
        M4_DIGIT_EX(4f4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float maxR_thred[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(minR_thred),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255),
        M4_DEFAULT(3),
        M4_DIGIT_EX(4f4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float  minR_thred[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(maxG_thred),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255),
        M4_DEFAULT(230),
        M4_DIGIT_EX(4f4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float  maxG_thred[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(minG_thred),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255),
        M4_DEFAULT(3),
        M4_DIGIT_EX(4f4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float  minG_thred[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(maxB_thred),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255),
        M4_DEFAULT(230),
        M4_DIGIT_EX(4f4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float maxB_thred[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(minB_thred),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255),
        M4_DEFAULT(3),
        M4_DIGIT_EX(4f4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float  minB_thred[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(maxY_thred),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255),
        M4_DEFAULT(230),
        M4_DIGIT_EX(4f4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float  maxY_thred[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(minY_thred),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255),
        M4_DEFAULT(3),
        M4_DIGIT_EX(4f4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float minY_thred[CALD_AWB_LV_NUM_MAX];
} awb_rgbySpace_cfg_t;

typedef struct awb_extRgWgt_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(wgtInculde_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,16),
        M4_DEFAULT(10),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(1),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    int wgtInculde_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT([0,0.5,2,4,16,32,64,256,1024,2048]),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float luma_val[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(weight),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,5),
        M4_DEFAULT([1,1,1,1,1,1,1,1,1,1]),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float weight[CALD_AWB_LV_NUM_MAX];
} awb_extRgWgt_t;


typedef struct awb_lgtSrcWgt_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(lgtSrcWgt_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,16),
        M4_DEFAULT(10),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(1),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    int lgtSrcWgt_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT([0,0.5,2,4,16,32,64,256,1024,2048]),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float luma_val[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(weight),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,1),
        M4_DEFAULT([1,1,1,1,1,1,1,1,1,1]),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float weight[CALD_AWB_LV_NUM_MAX];
} awb_lgtSrcWgt_t;


typedef struct awb_extRange_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(domain),
        M4_TYPE(enum),
        M4_ENUM_DEF(awb_wpSpace_mode_t),
        M4_DEFAULT(awbStats_uvWp_mode),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: high))  */
    awb_wpSpace_mode_t domain;
    /* M4_GENERIC_DESC(
        M4_ALIAS(mode),
        M4_TYPE(enum),
        M4_ENUM_DEF(awb_ext_range_mode_t),
        M4_DEFAULT(awb_wpFiltOut_mode),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: high))  */
    awb_ext_range_mode_t mode;
    /* M4_GENERIC_DESC(
        M4_ALIAS(wpRegion),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Parameters for filted out white points from XY or UV space \n
        Freq of use: high))  */
    awbStats_filtOutRegion_t wpRegion;
    /* M4_GENERIC_DESC(
        M4_ALIAS(wgtInculde),
        M4_TYPE(struct),
        M4_UI_MODULE(array_table_ui),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_extRgWgt_t wgtInculde;
} awb_extRange_region_t;

typedef struct awb_lum2wgt_lv_rto_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(perfectWpNum_rat),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    float perfectWpNum_rat;
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma2WpWgt_wgt),
        M4_TYPE(f32),
        M4_SIZE_EX(1,9),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(1),
        M4_DIGIT_EX(4f5),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    float luma2WpWgt_wgt[AWBSTATS_WPLUMAWGTCURVE_SEGMENT_MAX] ;
} awb_lum2wgt_lv_rto_t;

typedef struct awb_lum2wgt_lv_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT(0),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    float luma_val;
    /* M4_GENERIC_DESC(
        M4_ALIAS(ratioSet_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,8),
        M4_DEFAULT(8),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    int ratioSet_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(ratioSet),
        M4_TYPE(struct_list),
        M4_SIZE_EX(1,8),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(TODO))  */
    awb_lum2wgt_lv_rto_t ratioSet[CALD_AWB_LWR_NUM_MAX];
} awb_lum2wgt_lv_t;

typedef struct awb_lum2wgt_enTh_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(wpNum_rat),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0.004),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    float wpNum_rat;
    /* M4_GENERIC_DESC(
        M4_ALIAS(lumaVal_th),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT(64),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    unsigned int   lumaVal_th;
} awb_lum2wgt_enTh_t;

typedef struct awb_luma2WpWgt_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma2WpWgt_en),
        M4_TYPE(bool),
        M4_DEFAULT(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(with differernt luma ,the different weight in WP sum))  */
    bool luma2WpWgt_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma2WpWgtEn_th),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES( \n
        Freq of use: low))  */
    awb_lum2wgt_enTh_t luma2WpWgtEn_th;
#ifdef ISP_HW_V33
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma2WpWgt_ccm),
        M4_TYPE(f32),
        M4_SIZE_EX(3,3),
        M4_RANGE_EX(-8,8),
        M4_DEFAULT([1,0,0,0,1,0,0,0,1]),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    float luma2WpWgt_ccm[9];
#endif
    /* M4_GENERIC_DESC(
        M4_ALIAS(perfectWpBin),
        M4_TYPE(u8),
        M4_SIZE_EX(1,8),
        M4_RANGE_EX(0,1),
        M4_DEFAULT([0,0,0,1,1,1,1,0]),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    unsigned char  perfectWpBin[8];// true means the luma is appropriate
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma2WpWgt_luma),
        M4_TYPE(u8),
        M4_SIZE_EX(1,9),
        M4_RANGE_EX(0,255),
        M4_DEFAULT([0,16,32,64,96,128,192,224,240]),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    unsigned char luma2WpWgt_luma[AWBSTATS_WPLUMAWGTCURVE_SEGMENT_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma2WpWgt_lvSet_len),
        M4_TYPE(u8),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,16),
        M4_DEFAULT(5),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    int luma2WpWgt_lvSet_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma2WpWgt_lvSet),
        M4_TYPE(struct_list),
        M4_SIZE_EX(1,16),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: low))  */
    awb_lum2wgt_lv_t luma2WpWgt_lvSet[CALD_AWB_LV_NUM_MAX];
} awb_luma2WpWgt_t;



typedef struct awb_lv_wgt_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT([0,0.5,2,4,16,32,64,128,256,512,1024,2048,4096,8192,16384,32768]),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float luma_val[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(weight),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float weight[CALD_AWB_LV_NUM_MAX];
} awb_lv_wgt_t;

typedef struct awb_lgtSrcPrefWbgain_s {

    /* M4_GENERIC_DESC(
        M4_ALIAS(luma_val),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT([1024]),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    unsigned int luma_val;
    /* M4_GENERIC_DESC(
        M4_ALIAS(prf_wbgain),
        M4_TYPE(f32),
        M4_SIZE_EX(1,4),
        M4_RANGE_EX(0,8),
        M4_DEFAULT(1),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float prf_wbgain[4];
} awb_lgtSrcPrefWbgain_t;

typedef struct awb_lgtSrcPref_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(preferWgt),
        M4_TYPE(struct),
        M4_UI_MODULE(array_table_ui),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_lv_wgt_t preferWgt;
    /* M4_GENERIC_DESC(
        M4_ALIAS(preferWbGain_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,4),
        M4_DEFAULT(2),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    int preferWbGain_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(preferWbGain),
        M4_TYPE(struct_list),
        M4_SIZE_EX(1,4),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    awb_lgtSrcPrefWbgain_t preferWbGain[CALID_AWB_LGT_PREFGN_NUM_MAX];

} awb_lgtSrcPref_t;

typedef struct awb_bigNorWpWgt_lv_rto_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(ratioSet_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(1,8),
        M4_DEFAULT(4),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    int ratioSet_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(norWpNum_rat),
        M4_TYPE(f32),
        M4_SIZE_EX(1,8),
        M4_RANGE_EX(0,1),
        M4_DEFAULT([0,0.05,0.1,0.2,0.3,0.4,0.5,0.6]),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    float norWpNum_rat[CALD_AWB_LWR_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(bigWp_wgt),
        M4_TYPE(f32),
        M4_SIZE_EX(1,8),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    float bigWp_wgt[CALD_AWB_LWR_NUM_MAX];
} awb_bigNorWpWgt_lv_rto_t;

typedef struct awb_bigNorWpWgt_lv_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT(0),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    float luma_val;
    /* M4_GENERIC_DESC(
        M4_ALIAS(ratioSet),
        M4_TYPE(struct),
        M4_UI_MODULE(array_table_ui),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_bigNorWpWgt_lv_rto_t ratioSet;
} awb_bigNorWpWgt_lv_t;


typedef struct awb_bigNorWpWgt_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(bigNorWpWgt_lvSet_len),
        M4_TYPE(u8),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,16),
        M4_DEFAULT(5),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    int bigNorWpWgt_lvSet_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(bigNorWpWgt_lvSet),
        M4_TYPE(struct_list),
        M4_SIZE_EX(1,16),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_bigNorWpWgt_lv_t bigNorWpWgt_lvSet[CALD_AWB_LV_NUM_MAX];

} awb_bigNorWpWgt_t;

typedef struct awb_lgtSrc_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(name),
        M4_TYPE(string),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255),
        M4_DEFAULT("D50"),
        M4_DYNAMIC(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: high))  */
    char name[CALD_AWB_ILLUMINATION_NAME];
    /* M4_GENERIC_DESC(
        M4_ALIAS(doorType_mode),
        M4_TYPE(enum),
        M4_ENUM_DEF(awb_doortype_t),
        M4_DEFAULT(awb_doorType_ambiguity),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_doortype_t doorType_mode;
    /* M4_GENERIC_DESC(
        M4_ALIAS(standard_wbGain),
        M4_TYPE(f32),
        M4_SIZE_EX(1,4),
        M4_RANGE_EX(0,8),
        M4_DEFAULT(1),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float standard_wbGain[4];
    /* M4_GENERIC_DESC(
        M4_ALIAS(wpDct_uvSpace),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Parameters for detecting white points in UV space \n
        Freq of use: high))  */
    awbStats_uvRegion_t wpDct_uvSpace;
    /* M4_GENERIC_DESC(
        M4_ALIAS(wpDct_xySpace),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_xyWpDct_t wpDct_xySpace;
#ifndef ISP_HW_V33
    /* M4_GENERIC_DESC(
        M4_ALIAS(wpDct_rotYuvSpace),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awbStats_rotYuvRegion_t wpDct_rotYuvSpace;
#endif
    /* M4_GENERIC_DESC(
        M4_ALIAS(bigNorWpWgt),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_bigNorWpWgt_t bigNorWpWgt;
    /* M4_GENERIC_DESC(
        M4_ALIAS(lgtPrefer),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_lgtSrcPref_t lgtPrefer;
    /* M4_GENERIC_DESC(
        M4_ALIAS(lgtSrcWgt),
        M4_TYPE(struct),
        M4_UI_MODULE(array_table_ui),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_lgtSrcWgt_t lgtSrcWgt;
} awb_lgtSrc_t;



typedef struct awb_earlAct_s {
    // M4_BOOL_DESC("earlAct_en", "0");
    bool earlAct_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(mode),
        M4_TYPE(enum),
        M4_ENUM_DEF(awb_earlAct_mdoe_t),
        M4_DEFAULT(awb_earlActXyReg_auto_mode),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_earlAct_mdoe_t mode;
    /* M4_GENERIC_DESC(
        M4_ALIAS(norWpRegion),
        M4_SIZE_EX(1,4),
        M4_TYPE(struct_list),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Parameters for detecting normal white points in XY space \n
        Freq of use: high))  */
    awbStats_xyRegion_t norWpRegion[AWBSTATS_WPDCT_LS_NUM];
    /* M4_GENERIC_DESC(
        M4_ALIAS(bigWpRegion),
        M4_TYPE(struct_list),
        M4_SIZE_EX(1,4),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Parameters for big detecting white points in XY space \n
        Freq of use: high))  */
    awbStats_xyRegion_t bigWpRegion[AWBSTATS_WPDCT_LS_NUM];
} awb_earlAct_t;

typedef struct awb_rgbySpace_s{
        /* M4_GENERIC_DESC(
        M4_ALIAS(sw_awbCfg_rgbyLimit_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Enable white point detection in the UV space \n
        Freq of use: high))  */
    //reg:sw_rawawb_uv_en0
    bool sw_awbCfg_rgbyLimit_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(rgbyLimit),
        M4_TYPE(struct),
        M4_UI_MODULE(array_table_ui),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Parameters for detecting white points in rgb-y space\n
        Freq of use: high))  */
    awb_rgbySpace_cfg_t cfg;
}awb_rgbySpace_t;

typedef struct awb_extRange_region_s{
    /* M4_GENERIC_DESC(
        M4_ALIAS(hw_awbCfg_wpExtraLs_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Enable filter out specific white points from detected white points in xy space or uv space.\n
    Freq of use: high))  */
    //reg: sw_rawawb_exc_wp_region0/1/2/3/4/5/6_excen bit0
	bool hw_awbCfg_wpExtraLs_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(hw_awbCfg_wpFiltOut_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Enable filter out specific white points from detected white points in xy space or uv space.\n
    Freq of use: high))  */
    //reg: sw_rawawb_exc_wp_region0/1/2/3/4/5/6_excen bit0
	bool hw_awbCfg_wpFiltOut_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(wpRegionSet),
        M4_TYPE(struct_list),
        M4_SIZE_EX(1,7),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(several winow in uv or xy domain\n
        Freq of use: high))  */
    awb_extRange_region_t wpRegionSet[CALD_AWB_EXCRANGE_NUM_MAX];
}awb_extRange_t;
typedef struct awb_zoneWgt_s{
        /* M4_GENERIC_DESC(
        M4_ALIAS(hw_awbCfg_zoneWgt_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(It is perform weighted statistics on the zone weights of the normal white point when the bit is enabled.\n
        Freq of use: high))  */
	//reg:sw_rawawb_wp_blk_wei_en0
    bool hw_awbCfg_zoneWgt_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(hw_awbCfg_zone_wgt),
        M4_TYPE(u8),
        M4_SIZE_EX(15,15),
        M4_RANGE_EX(0,0x3F),
        M4_DEFAULT([6, 6, 6, 8, 8, 8, 8, 10, 8, 8, 8, 8, 6, 6, 6, 6, 6, 8, 8, 10, 10, 12, 12, 12, 10, 10, 8, 8, 6, 6, 6, 8, 10, 12, 14, 16, 18, 20, 18, 16, 14, 12, 10, 8, 6, 8, 8, 12, 16, 22, 26, 30, 32, 30, 26, 22, 16, 12, 8, 8, 8, 10, 14, 22, 28, 36, 42, 46, 42, 36, 28, 22, 14, 10, 8, 8, 10, 16, 26, 36, 46, 54, 58, 54, 46, 36, 26, 16, 10, 8, 8, 12, 18, 30, 42, 54, 63, 63, 63, 54, 42, 30, 18, 12, 8, 10, 12, 20, 32, 46, 58, 63, 63, 63, 58, 46, 32, 20, 12, 10, 8, 12, 18, 30, 42, 54, 63, 63, 63, 54, 42, 30, 18, 12, 8, 8, 10, 16, 26, 36, 46, 54, 58, 54, 46, 36, 26, 16, 10, 8, 8, 10, 14, 22, 28, 36, 42, 46, 42, 36, 28, 22, 14, 10, 8, 8, 8, 12, 16, 22, 26, 30, 32, 30, 26, 22, 16, 12, 8, 8, 6, 8, 10, 12, 14, 16, 18, 20, 18, 16, 14, 12, 10, 8, 6, 6, 6, 8, 8, 10, 10, 12, 12, 12, 10, 10, 8, 8, 6, 6, 6, 6, 6, 8, 8, 8, 8, 10, 8, 8, 8, 8, 6, 6, 6]),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(The weight of each zone in awb statistics..\n
        Freq of use: high))  */
    //reg:sw_rawawb_wp_blk_wei_w0~224
    unsigned char hw_awbCfg_zone_wgt[CALD_AWB_GRID_NUM_TOTAL];
}awb_zoneWgt_t;
typedef struct awb_Stats_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(hw_awbCfg_statsSrc_mode),
        M4_TYPE(enum),
        M4_ENUM_DEF(awbStats_src_mode_t),
        M4_DEFAULT(awbStats_drcOut_mode),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(The mode bit can be used to switch the source of the AWB statistics module.\n
        Reference enum types.\n
        Freq of use: high))  */
    awbStats_src_mode_t hw_awbCfg_statsSrc_mode;
    /* M4_GENERIC_DESC(
        M4_ALIAS(hw_awbCfg_lsc_en),
        M4_TYPE(bool),
        M4_DEFAULT(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(3),
        M4_NOTES(The enable bit of lsc in the awb statistics module.\nFreq of use: high))  */
	//reg:sw_rawlsc_bypass_en
    bool hw_awbCfg_lsc_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(hw_awbCfg_uvDct_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Enable white point detection in the UV space \n
        Freq of use: high))  */
    //reg:sw_rawawb_uv_en0
    bool hw_awbCfg_uvDct_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(hw_awbCfg_xyDct_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Enable white point detection in the XY space\n
        Freq of use: high))  */
    //reg:sw_rawawb_xy_en0
    bool hw_awbCfg_xyDct_en;
 #ifndef ISP_HW_V33
    /* M4_GENERIC_DESC(
        M4_ALIAS(hw_awbCfg_rotYuvDct_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Enable white point detection in the rotate YUV space\n
        Freq of use: high))  */
    //reg:sw_rawawb_3dyuv_en0
    bool hw_awbCfg_rotYuvDct_en;
 #endif
   /* M4_GENERIC_DESC(
        M4_ALIAS(sw_awbCfg_lgtPrefer_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: high))  */
	bool sw_awbCfg_lgtPrefer_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(sw_awbCfg_lgtSrcWgt_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: high))  */
	bool sw_awbCfg_lgtSrcWgt_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(hw_awbCfg_ds_mode),
        M4_TYPE(enum),
        M4_ENUM_DEF(awbStats_ds_mode_t),
        M4_DEFAULT(awbStats_ds_8x8),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(The mode bit is used to switch the way bayer raw is converted to rgb.\n
        Reference enum types.\n
        Freq of use: high))  */
     //reg:sw_rawawb_ds16x8_mode_en+sw_rawawb_wind_size
    awbStats_ds_mode_t hw_awbCfg_ds_mode;
    /* M4_GENERIC_DESC(
        M4_ALIAS(mainWin),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(stat window\n
        Freq of use: high))  */
    awbStats_win_t mainWin;
    /* M4_GENERIC_DESC(
        M4_ALIAS(rgbyLimit),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Parameters for detecting white points in rgb-y space\n
        Freq of use: high))  */
    awb_rgbySpace_t rgbyLimit;
    /* M4_GENERIC_DESC(
        M4_ALIAS(rgb2xy),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(1),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Parameters for converting rgb space to xy space\n
        Freq of use: high))  */
    awb_rgb2xy_para_t rgb2xy;
#ifndef ISP_HW_V33
     /* M4_GENERIC_DESC(
        M4_ALIAS(hw_awbCfg_rgb2RYuv_coeff),
        M4_TYPE(f32),
        M4_SIZE_EX(3,4),
        M4_RANGE_EX(-255,255),
        M4_DEFAULT(0),
        M4_HIDE_EX(1),
        M4_RO(0),
        M4_ORDER(0),
        M4_DIGIT_EX(6f9),
        M4_NOTES(RGB2ROTYUV coefficient mat.\n
        Freq of use: high))  */
    float hw_awbCfg_rgb2RotYuv_coeff[12];
#endif
    /* M4_GENERIC_DESC(
        M4_ALIAS(extraWpRange),
        M4_TYPE(struct),
        M4_SIZE_EX(1,1),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(several winow in uv or xy domain\n
        Freq of use: high))  */
    awb_extRange_t extraWpRange;
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma2WpWgt),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(several winow in uv or xy domain\n
        Freq of use: high))  */
    awb_luma2WpWgt_t luma2WpWgt;
    /* M4_GENERIC_DESC(
        M4_ALIAS(earlierAwbAct),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(s\n
        Freq of use: high))  */
    awb_earlAct_t earlierAwbAct;
    /* M4_GENERIC_DESC(
        M4_ALIAS(blc2ForAwb),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(The enable bit of blc in the awb statistics module\n
        Freq of use: high))  */
    awb_blc_t blc2ForAwb;
    /* M4_GENERIC_DESC(
        M4_ALIAS(lightSources_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,14),
        M4_DEFAULT(7),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    int lightSources_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(lightSources),
        M4_TYPE(struct_list),
        M4_SIZE_EX(1,14),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(TODO))  */
    awb_lgtSrc_t lightSources[CALD_AWB_LS_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(zoneWgt),
        M4_TYPE(struct),
        M4_SIZE_EX(1,1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(The weight of each zone in awb statistics..\n
        Freq of use: high))  */
    awb_zoneWgt_t zoneWgt;
    /* M4_GENERIC_DESC(
        M4_ALIAS(hw_awbCfg_zoneStats_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Enable filter out specific white points from detected white points in xy space or uv space.\n
        Freq of use: high))  */
    //reg: sw_rawawb_exc_wp_region0/1/2/3/4/5/6_excen bit0
	bool hw_awbCfg_zoneStats_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(hw_awbCfg_zoneStatsSrc_mode),
        M4_TYPE(enum),
        M4_ENUM_DEF(awbStats_zoneStatsSrc_mode_t),
        M4_DEFAULT(awbStats_pixAll_mode),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(Measure mode for block stat. Reference enum types.\nFreq of use: high))  */
    //reg:sw_rawawb_blk_measure_mode
    awbStats_pixEngineSrc_mode_t hw_awbCfg_zoneStatsSrc_mode;
} awb_Stats_t;


typedef struct awb_smartRun_cfg_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(cfg_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,16),
        M4_DEFAULT(10),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(1),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    int cfg_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT([0,0.5,2,4,16,32,64,128,256,512,1024,2048,4096,8192,16384,32768]),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float luma_val[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(lvVar_th),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255),
        M4_DEFAULT(0.001),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float lvVar_th[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(wbGainAlgUdDiff_th),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,4),
        M4_DEFAULT(0.005),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wbGainAlgUdDiff_th[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(wbGainAlgDpDiff_th),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,4),
        M4_DEFAULT(0.005),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wbGainAlgDpDiff_th[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(wbGainHwDiffTh),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,4),
        M4_DEFAULT(0.05),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wbGainHwDiff_th[CALD_AWB_LV_NUM_MAX];
} awb_smartRun_cfg_t;

typedef struct awb_smartRun_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(smartRun_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    bool  tolerance_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(cfg),
        M4_TYPE(struct),
        M4_UI_MODULE(array_table_ui),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_smartRun_cfg_t cfg;
} awb_smartRun_t;


typedef struct awb_runinterval_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(runInterval_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,16),
        M4_DEFAULT(10),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(1),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    int runInterval_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT([0,0.5,2,4,16,32,64,128,256,512,1024,2048,4096,8192,16384,32768]),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float luma_val[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(interval_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255),
        M4_DEFAULT(0),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float interval_val[CALD_AWB_LV_NUM_MAX];
}  awb_runinterval_t;

typedef struct awb_cctLutCfg_Lv_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(ctlData),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT(4),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float ctlData;
    /* M4_GENERIC_DESC(
        M4_ALIAS(rgct_ds_in),
        M4_TYPE(f32),
        M4_SIZE_EX(1,9),
        M4_RANGE_EX(0,10000),
        M4_DEFAULT([0.8,1.1,1.4,1.7,2,2.3,2.6,2.9,3.2]),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float rgct_ds_in[CALD_AWB_RGCT_GRID_NUM];
    /* M4_GENERIC_DESC(
        M4_ALIAS(bgcri_ds_in),
        M4_TYPE(f32),
        M4_SIZE_EX(1,11),
        M4_RANGE_EX(-2,8),
        M4_DEFAULT([4.2,3.9,3.6,3.3,3,2.7,2.4,2.1,1.8,1.5,1.2]),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float bgcri_ds_in[CALD_AWB_BGCRI_GRID_NUM];
    /* M4_GENERIC_DESC(
        M4_ALIAS(rgct_lut_out),
        M4_TYPE(f32),
        M4_SIZE_EX(11,9),
        M4_RANGE_EX(0,10000),
        M4_DEFAULT([0.8,1.1,1.4,1.7,2,2.3,2.6,2.9,3.2,0.8,1.1,1.4,1.7,2,2.3,2.6,2.9,3.2,0.8,1.1,1.4,1.7,2,2.3,2.6,2.9,3.2,0.8,1.1,1.4,1.7,2,2.3,2.6,2.9,3.2,0.8,1.1,1.4,1.7,2,2.3,2.6,2.9,3.2,0.8,1.1,1.4,1.7,2,2.3,2.6,2.9,3.2,0.8,1.1,1.4,1.7,2,2.3,2.6,2.9,3.2,0.8,1.1,1.4,1.7,2,2.3,2.6,2.9,3.2,0.8,1.1,1.4,1.7,2,2.3,2.6,2.9,3.2,0.8,1.1,1.4,1.7,2,2.3,2.6,2.9,3.2,0.8,1.1,1.4,1.7,2,2.3,2.6,2.9,3.2]),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float rgct_lut_out[CALD_AWB_RGCT_GRID_NUM*CALD_AWB_BGCRI_GRID_NUM];
    /* M4_GENERIC_DESC(
        M4_ALIAS(bgcri_lut_out),
        M4_TYPE(f32),
        M4_SIZE_EX(11,9),
        M4_RANGE_EX(-2,8),
        M4_DEFAULT([4.2,4.2,4.2,4.2,4.2,4.2,4.2,4.2,4.2,3.9,3.9,3.9,3.9,3.9,3.9,3.9,3.9,3.9,3.6,3.6,3.6,3.6,3.6,3.6,3.6,3.6,3.6,3.3,3.3,3.3,3.3,3.3,3.3,3.3,3.3,3.3,3,3,3,3,3,3,3,3,3,2.7,2.7,2.7,2.7,2.7,2.7,2.7,2.7,2.7,2.4,2.4,2.4,2.4,2.4,2.4,2.4,2.4,2.4,2.1,2.1,2.1,2.1,2.1,2.1,2.1,2.1,2.1,1.8,1.8,1.8,1.8,1.8,1.8,1.8,1.8,1.8,1.5,1.5,1.5,1.5,1.5,1.5,1.5,1.5,1.5,1.2,1.2,1.2,1.2,1.2,1.2,1.2,1.2,1.2]),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float bgcri_lut_out[CALD_AWB_RGCT_GRID_NUM*CALD_AWB_BGCRI_GRID_NUM];
} awb_cctLutCfg_Lv_t;

typedef struct awb_gainAdjust_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(awbGnAdjst_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    bool awbGnAdjst_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(ctrlDataSelt_mode),
        M4_TYPE(enum),
        M4_ENUM_DEF(awb_ctrlDatSelt_t),
        M4_DEFAULT(awb_ctrlData_lv),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_ctrlDatSelt_t ctrlDataSelt_mode;
    /* M4_GENERIC_DESC(
        M4_ALIAS(adjDataSelt_mode),
        M4_TYPE(enum),
        M4_ENUM_DEF(awb_GainAdjDatSelt_t),
        M4_DEFAULT(awb_GainAdjDatSelt_gain),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_GainAdjDatSelt_t adjDataSelt_mode;
    /* M4_GENERIC_DESC(
        M4_ALIAS(lutAll_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,8),
        M4_DEFAULT(4),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    int lutAll_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(lutAll),
        M4_TYPE(struct_list),
        M4_SIZE_EX(1,8),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(TODO))  */
    awb_cctLutCfg_Lv_t lutAll[CALID_AWB_CT_LUT_NUM];

} awb_gainAdjust_t;

typedef struct awb_gainClip_cfg_s {
     /* M4_GENERIC_DESC(
        M4_ALIAS(cfg_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,8),
        M4_DEFAULT(11),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    int cfg_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(cct),
        M4_TYPE(f32),
        M4_SIZE_EX(1,11),
        M4_RANGE_EX(0,10000),
        M4_DEFAULT([0,1000,2000,3000,4000,5000,6000,7000,8000,9000,10000]),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float cct[CALID_AWB_CT_GRID_NUM];
    /* M4_GENERIC_DESC(
        M4_ALIAS(cri_bound_up),
        M4_TYPE(f32),
        M4_SIZE_EX(1,11),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0.3),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float cri_bound_up[CALID_AWB_CT_GRID_NUM];
    /* M4_GENERIC_DESC(
        M4_ALIAS(cri_bound_up),
        M4_TYPE(f32),
        M4_SIZE_EX(1,11),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0.3),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float cri_bound_low[CALID_AWB_CT_GRID_NUM];
} awb_gainClip_cfg_t;

typedef struct awb_gainClip_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(awbGnClip_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    bool awbGnClip_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(cfg),
        M4_TYPE(struct),
        M4_UI_MODULE(array_table_ui),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    awb_gainClip_cfg_t cfg;

} awb_gainClip_t;

typedef struct awb_div_wpTh_s {
     /* M4_GENERIC_DESC(
        M4_ALIAS(wpNumTh_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,16),
        M4_DEFAULT(10),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(1),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    int wpNumTh_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT([0,0.5,2,4,16,32,64,128,256,512,1024,2048,4096,8192,16384,32768]),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float luma_val[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(low_rat),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0.0015),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float low_rat[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(high_rat),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0.00216),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float high_rat[CALD_AWB_LV_NUM_MAX];
} awb_div_wpTh_t;

typedef struct awb_div_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(wpNumTh),
        M4_TYPE(struct),
        M4_UI_MODULE(array_table_ui),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_div_wpTh_t wpNumTh;
} awb_div_t;

typedef struct awb_xyRgStb_wpTh_s {
     /* M4_GENERIC_DESC(
        M4_ALIAS(wpNumTh_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,8),
        M4_DEFAULT(10),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(1),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    int wpNumTh_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT([0,0.5,2,4,16,32,64,128,256,512,1024,2048,4096,8192,16384,32768]),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float luma_val[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(forBigType),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(216),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float forBigType[CALD_AWB_LV_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(forExtraType),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(216),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float forExtraType[CALD_AWB_LV_NUM_MAX];
} awb_xyRgStb_wpTh_t;

typedef struct awb_xyRgStb_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(xyRgStable_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    bool xyRgStable_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(wpNumTh),
        M4_TYPE(struct),
        M4_UI_MODULE(array_table_ui),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_xyRgStb_wpTh_t wpNumTh;
     /* M4_GENERIC_DESC(
        M4_ALIAS(xyTypeList_size),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,65535),
        M4_DEFAULT(50),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    int xyTypeList_size;
     /* M4_GENERIC_DESC(
        M4_ALIAS(varianceLuma_th),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,100),
        M4_DEFAULT(0.06),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float varianceLuma_th;
} awb_xyRgStb_t;

typedef struct awb_prefereNgt_wbGain_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(prefereNgtwbGain_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    bool prefereNgtwbGain_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(wbGain),
        M4_TYPE(f32),
        M4_SIZE_EX(1,4),
        M4_RANGE_EX(0,8),
        M4_DEFAULT(1),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wbGain[4];
    /* M4_GENERIC_DESC(
        M4_ALIAS(wgt),
        M4_TYPE(struct),
        M4_UI_MODULE(array_table_ui),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_lv_wgt_t wgt;
} awb_prefereNgt_wbGain_t;

typedef struct awb_sgc_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(sgc_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    bool sgc_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(mode),
        M4_TYPE(enum),
        M4_ENUM_DEF(awb_sgc_mode_e),
        M4_DEFAULT(awb_sgcCall_initial),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES())  */
    awb_sgc_mode_e mode;
     /* M4_GENERIC_DESC(
        M4_ALIAS(colorBlock_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,16),
        M4_DEFAULT(10),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    int colorBlock_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(colorBlock),
        M4_TYPE(struct_list),
        M4_SIZE_EX(1,16),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(TODO))  */
    awb_sgc_cBlk_t colorBlock[CALD_AWB_SGC_NUM_MAX];
     /* M4_GENERIC_DESC(
        M4_ALIAS(lsUsedForEstimation_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,16),
        M4_DEFAULT(10),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    int lsUsedForEstimation_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(lsUsedForEstimation),
        M4_TYPE(struct_list),
        M4_SIZE_EX(1,14),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(TODO))  */
    awb_sgc_lgtSrc_t lsUsedForEstimation[CALD_AWB_LS_NUM_MAX];
     /* M4_GENERIC_DESC(
        M4_ALIAS(illuEstListSize),
        M4_TYPE(u16),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(1,255),
        M4_DEFAULT(10),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    unsigned short illuEstList_size;
     /* M4_GENERIC_DESC(
        M4_ALIAS(alpha),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(1),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float alpha;
     /* M4_GENERIC_DESC(
        M4_ALIAS(wgtClrGradX),
        M4_TYPE(f32),
        M4_SIZE_EX(1,6),
        M4_RANGE_EX(0,10000),
        M4_DEFAULT([50, 100, 150, 200, 300, 600]),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wgtClrGradX[AWB_SGC_GRAD_GRID_NUM];
     /* M4_GENERIC_DESC(
        M4_ALIAS(wgtClrGradY),
        M4_TYPE(f32),
        M4_SIZE_EX(1,6),
        M4_RANGE_EX(0,1),
        M4_DEFAULT([1, 1, 0.5, 0.5, 0.2, 0]),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wgtClrGradY[AWB_SGC_GRAD_GRID_NUM];
     /* M4_GENERIC_DESC(
        M4_ALIAS(wgtDistX),
        M4_TYPE(f32),
        M4_SIZE_EX(1,6),
        M4_RANGE_EX(0,10000),
        M4_DEFAULT([200, 400, 900, 1200, 2000, 3000]),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wgtDistX[AWB_SGC_DIS_GRID_NUM];
     /* M4_GENERIC_DESC(
        M4_ALIAS(wgtDistCt),
        M4_TYPE(f32),
        M4_SIZE_EX(1,3),
        M4_RANGE_EX(0,10000),
        M4_DEFAULT([2000, 5000, 6500]),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wgtDistCt[AWB_SGC_CT_GRID_NUM];
     /* M4_GENERIC_DESC(
        M4_ALIAS(wgtDistHCtY),
        M4_TYPE(f32),
        M4_SIZE_EX(1,6),
        M4_RANGE_EX(0,1),
        M4_DEFAULT([1, 1, 1, 0, 0, 0]),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wgtDistHCtY[AWB_SGC_DIS_GRID_NUM];
     /* M4_GENERIC_DESC(
        M4_ALIAS(wgtDistMCtY),
        M4_TYPE(f32),
        M4_SIZE_EX(1,6),
        M4_RANGE_EX(0,1),
        M4_DEFAULT([1, 1, 1, 0, 0, 0]),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wgtDistMCtY[AWB_SGC_DIS_GRID_NUM];
     /* M4_GENERIC_DESC(
        M4_ALIAS(wgtDistLCtY),
        M4_TYPE(f32),
        M4_SIZE_EX(1,6),
        M4_RANGE_EX(0,1),
        M4_DEFAULT([1, 1, 1, 0, 0, 0]),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wgtDistLCtY[AWB_SGC_DIS_GRID_NUM];
     /* M4_GENERIC_DESC(
        M4_ALIAS(wgtLvX),
        M4_TYPE(f32),
        M4_SIZE_EX(1,8),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT([0, 32,64,128, 256,2048,4096,8192]),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wgtLvX[AWB_SGC_LV_GRID_NUM];
     /* M4_GENERIC_DESC(
        M4_ALIAS(wgtLvY),
        M4_TYPE(f32),
        M4_SIZE_EX(1,8),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT([0, 0.5, 1, 1, 1, 1, 1, 1]),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wgtLvY[AWB_SGC_LV_GRID_NUM];
     /* M4_GENERIC_DESC(
        M4_ALIAS(wgtWpNumthX),
        M4_TYPE(f32),
        M4_SIZE_EX(1,6),
        M4_RANGE_EX(0,1),
        M4_DEFAULT([0.0002, 0.001 , 0.005 , 0.01  , 0.02  , 0.02  ]),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wgtWpNumthX[AWB_SGC_WPNUM_GRID_NUM];
     /* M4_GENERIC_DESC(
        M4_ALIAS(wgtWpNumthY),
        M4_TYPE(f32),
        M4_SIZE_EX(1,6),
        M4_RANGE_EX(0,1),
        M4_DEFAULT([1, 1, 0.5, 0.1, 0, 0]),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float wgtWpNumthY[AWB_SGC_WPNUM_GRID_NUM];
     /* M4_GENERIC_DESC(
        M4_ALIAS(illuMchPrt),
        M4_TYPE(s32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(-1,255),
        M4_DEFAULT(0),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    int illuMchPrt;
     /* M4_GENERIC_DESC(
        M4_ALIAS(useSgcResth),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0.6),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float useSgcResth;
     /* M4_GENERIC_DESC(
        M4_ALIAS(updateDpWbgnTh),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0.02),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float updateDpWbgnTh;
     /* M4_GENERIC_DESC(
        M4_ALIAS(updateDpWbgnTh2),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0.8),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float updateDpWbgnTh2;
     /* M4_GENERIC_DESC(
        M4_ALIAS(updateEstWbgnTh),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0.02),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float updateEstWbgnTh;
} awb_sgc_t;


typedef struct awb_probCal_dist_s {
      /* M4_GENERIC_DESC(
        M4_ALIAS(low_th),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,8),
        M4_DEFAULT(0.0269),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float low_th;
    /* M4_GENERIC_DESC(
        M4_ALIAS(high_th),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,8),
        M4_DEFAULT(6.6124),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(threshold for distance probality calculation\n
            Freq of use: high)) */
    float high_th;
} awb_probCal_dist_t;

typedef struct awb_probCal_lv_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(low_th),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT(30000),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
            Freq of use: high)) */
    unsigned int low_th;
    /* M4_GENERIC_DESC(
        M4_ALIAS(high_th),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT(45745),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES( threshold for luminance probality calculation\n
            Freq of use: high)) */
    unsigned int high_th;
} awb_probCal_lv_t;

typedef struct awb_probCal_wp_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(wpNum_rat),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0.0031),
        M4_DIGIT_EX(6),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
            Freq of use: high)) */
    float  wpNum_rat;
    /* M4_GENERIC_DESC(
        M4_ALIAS(lgtSrc_rat),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0.2),
        M4_DIGIT_EX(6),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
            Freq of use: high)) */
    float  lgtSrc_rat;
} awb_probCal_wp_t;


typedef struct awb_probCal_s{
    /* M4_GENERIC_DESC(
        M4_ALIAS(dist),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_probCal_dist_t dist;
    /* M4_GENERIC_DESC(
        M4_ALIAS(lv),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_probCal_lv_t lv;
    /* M4_GENERIC_DESC(
        M4_ALIAS(wpNum),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_probCal_wp_t wpNum;
}awb_probCal_t;

//ax+by-c=0;
typedef struct awb_line_s {
    /* M4_GENERIC_DESC(
    M4_ALIAS(a),
    M4_TYPE(f32),
    M4_SIZE_EX(1,1),
    M4_RANGE_EX(-2147483648,2147483647),
    M4_DEFAULT(1),
    M4_DIGIT_EX(6),
    M4_HIDE_EX(0),
    M4_RO(0),
    M4_ORDER(0),
    M4_NOTES(.\n
    Freq of use: low))  */
    float a;
    /* M4_GENERIC_DESC(
    M4_ALIAS(b),
    M4_TYPE(f32),
    M4_SIZE_EX(1,1),
    M4_RANGE_EX(-2147483648,2147483647),
    M4_DEFAULT(1),
    M4_DIGIT_EX(6),
    M4_HIDE_EX(0),
    M4_RO(0),
    M4_ORDER(0),
    M4_NOTES(.\n
    Freq of use: low))  */
    float b;
    /* M4_GENERIC_DESC(
    M4_ALIAS(c),
    M4_TYPE(f32),
    M4_SIZE_EX(1,1),
    M4_RANGE_EX(-2147483648,2147483647),
    M4_DEFAULT(1),
    M4_DIGIT_EX(6),
    M4_HIDE_EX(0),
    M4_RO(0),
    M4_ORDER(0),
    M4_NOTES(.\n
    Freq of use: low))  */
    float c;
} awb_line_t;

typedef struct awb_advSiteRec_s{
    /* M4_GENERIC_DESC(
        M4_ALIAS(advSiteRec_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    bool  advSiteRec_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(kpRecFrm_num),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255),
        M4_DEFAULT(3),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
            Freq of use: high)) */
    unsigned int kpRecFrm_num;
    /* M4_GENERIC_DESC(
        M4_ALIAS(advSiteInfoName),
        M4_TYPE(string),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255),
        M4_DEFAULT( "/tmp/advSiteInfo"),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
            M4_NOTES(.\n
        Freq of use: low))  */
    char  advSiteInfo_name[100];
    /* M4_GENERIC_DESC(
        M4_ALIAS(smartAdv_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_DEFAULT(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
            Freq of use: high)) */
    bool  smartAdv_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(wbGain_th),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,8),
        M4_DEFAULT(0.2),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
            Freq of use: high)) */
    float wbGain_th;
    /* M4_GENERIC_DESC(
        M4_ALIAS(lvValue_th),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255),
        M4_DEFAULT(2),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
            Freq of use: high)) */
    float lvValue_th;
}awb_advSiteRec_t;
typedef struct awb_ctCalc_s{
      /* M4_GENERIC_DESC(
        M4_ALIAS(lineRgBg),
        M4_TYPE(struct),
        M4_SIZE_EX(1,1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: high))  */
     awb_line_t lineRgBg;
     /* M4_GENERIC_DESC(
        M4_ALIAS(lineRgProjCCT),
        M4_TYPE(struct),
        M4_SIZE_EX(1,1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: high))  */
     awb_line_t lineRgProjCCT;
}awb_ctCalc_t;

typedef struct awb_dayLgtClip_Cfg_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(awbGnDLgtClip_en),
        M4_TYPE(bool),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,1),
        M4_DEFAULT("0"),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    bool  awbGnDLgtClip_en;
    /* M4_GENERIC_DESC(
        M4_ALIAS(outdoor_cct_min),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,10000),
        M4_DEFAULT("5000"),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(.\n
        Freq of use: low))  */
    float outdoor_cct_min;
} awb_dayLgtClip_Cfg_t;

typedef struct awb_hstrGainCalc_s{
     /* M4_GENERIC_DESC(
        M4_ALIAS(hstrGainCalc_wgt_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,16),
        M4_DEFAULT(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(2),
        M4_NOTES(.\n
        Freq of use: high))  */
    int hstrGainCalc_wgt_len;
     /* M4_GENERIC_DESC(
        M4_ALIAS(hstrGainCalc_wgt),
        M4_TYPE(f32),
        M4_SIZE_EX(1,16),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0.25),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(1),
        M4_NOTES(.\n
        Freq of use: high))  */
    float hstrGainCalc_wgt[CALD_AWB_LV_NUM_MAX];
}awb_hstrGainCalc_t;

typedef struct awb_refWbgain_s {

    /* M4_GENERIC_DESC(
        M4_ALIAS(luma_val),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT([1024]),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    unsigned int luma_val;
    /* M4_GENERIC_DESC(
        M4_ALIAS(ref_wbgain),
        M4_TYPE(f32),
        M4_SIZE_EX(1,4),
        M4_RANGE_EX(0,8),
        M4_DEFAULT(1),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float ref_wbgain[4];
} awb_refWbgain_t;

typedef struct awb_wbGnType1Calc_s{
    /* M4_GENERIC_DESC(
        M4_ALIAS(preferWbGain_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,4),
        M4_DEFAULT(3),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    int refWbGain_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(refWbGain),
        M4_TYPE(struct_list),
        M4_SIZE_EX(1,4),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    awb_refWbgain_t refWbGain[CALID_AWB_LGT_PREFGN_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(hstrGainCalc),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_hstrGainCalc_t hstrGainCalc;
    /* M4_GENERIC_DESC(
        M4_ALIAS(sgc),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_sgc_t sgc;
}awb_wbGnType1Calc_t;


typedef struct awb_wbGnType3Calc_s{
    /* M4_GENERIC_DESC(
        M4_ALIAS(lgtSrcProcCal),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_probCal_t lgtSrcProcCal;
    /* M4_GENERIC_DESC(
        M4_ALIAS(prefereNgtwbGain),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(3),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_prefereNgt_wbGain_t prefereNgtwbGain;
}awb_wbGnType3Calc_t;

typedef struct awb_extWgt_lv_rto_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(extWgtGnRto_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,7),
        M4_DEFAULT(4),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    int extWgtGnRto_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(bigWpNum_rat),
        M4_TYPE(f32),
        M4_SIZE_EX(1,7),
        M4_RANGE_EX(0,1),
        M4_DEFAULT([0,0.05,0.1,0.2,0.3,0.4,0.5,0.6]),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    float bigWpNum_rat[CALID_AWB_GNEXT_RTO_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(ext_wgt),
        M4_TYPE(f32),
        M4_SIZE_EX(1,7),
        M4_RANGE_EX(0,1),
        M4_DEFAULT(0),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    float ext_wgt[CALID_AWB_GNEXT_RTO_NUM_MAX];
}awb_extWgt_lv_rto_t;

typedef struct awb_extWgt_lv_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(luma_val),
        M4_TYPE(f32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,255000),
        M4_DEFAULT(0),
        M4_DIGIT_EX(1),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float luma_val;
    /* M4_GENERIC_DESC(
        M4_ALIAS(extWgtGnRto),
        M4_TYPE(struct),
        M4_UI_MODULE(array_table_ui),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_extWgt_lv_rto_t extWgtGnRto;
}awb_extWgt_lv_t;


typedef struct awb_wbGnExtrCalc_s{
    /* M4_GENERIC_DESC(
        M4_ALIAS(ext_wbGain),
        M4_TYPE(f32),
        M4_SIZE_EX(1,4),
        M4_RANGE_EX(0,8),
        M4_DEFAULT(1),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float ext_wbGain[4];
    /* M4_GENERIC_DESC(
        M4_ALIAS(extWgtGnLv_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,4),
        M4_DEFAULT(4),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: low))  */
    int extWgtGnLv_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(extWgtGnLv),
        M4_TYPE(struct_list),
        M4_SIZE_EX(1,16),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    awb_extWgt_lv_t extWgtGnLv[CALD_AWB_LV_NUM_MAX];
}awb_wbGnExtrCalc_t;

typedef struct awb_gainCalcStep_s {
    /* M4_GENERIC_DESC(
        M4_ALIAS(gnCalc_method),
        M4_TYPE(enum),
        M4_ENUM_DEF(awb_ganCalcMethod_e),
        M4_DEFAULT(awb_gan_calc_method_auto),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_ganCalcMethod_e gnCalc_method;
    /* M4_GENERIC_DESC(
        M4_ALIAS(division),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_div_t division;
    /* M4_GENERIC_DESC(
        M4_ALIAS(wbGnType1),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_wbGnType1Calc_t wbGnType1;
    /* M4_GENERIC_DESC(
        M4_ALIAS(wbGnType3),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_wbGnType3Calc_t wbGnType3;
    /* M4_GENERIC_DESC(
        M4_ALIAS(wbGnExt_len),
        M4_TYPE(u32),
        M4_SIZE_EX(1,1),
        M4_RANGE_EX(0,7),
        M4_DEFAULT(4),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    int wbGnExt_len;
    /* M4_GENERIC_DESC(
        M4_ALIAS(refWbGain),
        M4_TYPE(struct_list),
        M4_SIZE_EX(1,7),
        M4_DIGIT_EX(0),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    awb_wbGnExtrCalc_t wbGnExt[CALID_AWB_GNEXT_GN_NUM_MAX];
    /* M4_GENERIC_DESC(
        M4_ALIAS(wbGainDaylightClip),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(4),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_dayLgtClip_Cfg_t wbGainDaylightClip;
    /* M4_GENERIC_DESC(
        M4_ALIAS(wbGainClip),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(5),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_gainClip_t wbGainClip;
    /* M4_GENERIC_DESC(
        M4_ALIAS(wbGainAdjust),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(6),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_gainAdjust_t wbGainAdjust;
    /* M4_GENERIC_DESC(
        M4_ALIAS(wbGainOffset),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(7),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_gainOffset_t wbGainOffset;
    /* M4_GENERIC_DESC(
        M4_ALIAS(dampFactor),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(8),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_dampFactor_t dampFactor;
} awb_gainCalcStep_t;


typedef struct awb_gainCalcOth_s{
    /* M4_GENERIC_DESC(
        M4_ALIAS(fstFrm_wbgain),
        M4_TYPE(f32),
        M4_SIZE_EX(1,4),
        M4_RANGE_EX(0,8),
        M4_DEFAULT(1),
        M4_DIGIT_EX(4),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(T\n
        Freq of use: high))  */
    float fstFrm_wbgain[4];
    /* M4_GENERIC_DESC(
        M4_ALIAS(advSiteRec),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_advSiteRec_t advSiteRec;
        /* M4_GENERIC_DESC(
        M4_ALIAS(tolerance),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_smartRun_t tolerance;
    /* M4_GENERIC_DESC(
        M4_ALIAS(runInterval),
        M4_TYPE(struct),
        M4_UI_MODULE(array_table_ui),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_runinterval_t runInterval;
    /* M4_GENERIC_DESC(
        M4_ALIAS(converged),
        M4_TYPE(struct),
        M4_UI_MODULE(array_table_ui),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(0),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_converge_t converged;
    /* M4_GENERIC_DESC(
        M4_ALIAS(ctCalc),
        M4_TYPE(struct),
        M4_UI_MODULE(normal_ui_style),
        M4_HIDE_EX(0),
        M4_RO(0),
        M4_ORDER(10),
        M4_NOTES(\n
        Freq of use: high))  */
    awb_ctCalc_t ctCalc;
    //awb_xyRgStb_t xyRegionStableSelection;
}awb_gainCalcOth_t;




//RKAIQ_END_DECLARE

#endif
