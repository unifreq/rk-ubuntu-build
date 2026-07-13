/****************************************************************************
 *
 *    Copyright (c) 2022 by Rockchip Corp.  All rights reserved.
 *
 *    The material in this file is confidential and contains trade secrets
 *    of Rockchip Corporation. This is proprietary information owned by
 *    Rockchip Corporation. No part of this work may be disclosed,
 *    reproduced, copied, transmitted, or used in any way for any purpose,
 *    without the express written permission of Rockchip Corporation.
 *
 *****************************************************************************/

#ifndef __ROCKIVA_ONE_H__
#define __ROCKIVA_ONE_H__

#include "rockiva_common.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 结果回调函数
 * 
 */
typedef void (*ROCKIVA_ONE_ResultCallback)(const char* result, const RockIvaExecuteStatus status, void* userdata);

/**
 * @brief 帧释放回调函数
 * 
 */
typedef void (*ROCKIVA_ONE_FrameReleaseCallback)(const RockIvaReleaseFrames* releaseFrames, void* userdata);

typedef struct
{
    ROCKIVA_ONE_ResultCallback resultCallback;
    ROCKIVA_ONE_FrameReleaseCallback releaseCallback;
} RockIvaOneCallback;

/**
 * @brief 通过json配置文件进行初始化
 * 
 * @param handle [OUT] 待初始化handle
 * @param jsonString [IN] json配置字符串
 * @param callback [IN] 回调
 * @param userdata [IN] 用户自定义数据
 * @return RockIvaRetCode 
 */
RockIvaRetCode ROCKIVA_ONE_Init(RockIvaHandle* handle, const char* jsonString, RockIvaOneCallback callback,
                                void* userdata);

/**
 * @brief 释放
 * 
 * @param handle [IN] handle
 * @return RockIvaRetCode 
 */
RockIvaRetCode ROCKIVA_ONE_Release(RockIvaHandle handle);

/**
 * @brief 检查json字符串中某节点是否存在
 * 
 * @param jsonStr [IN] 结果json字符串
 * @param keyPathFmt [IN] 节点路径（例如：faceDetResult/faceInfo）
 * @param ... 
 * @return RockIvaRetCode 
 */
RockIvaRetCode ROCKIVA_ONE_CheckExist(const char* jsonStr, const char* keyPathFmt, ...);

/**
 * @brief 获取int类型数据
 * 
 * @param jsonStr [IN] 结果json字符串
 * @param value [OUT] 结果值
 * @param defVal [IN] 默认值
 * @param keyPathFmt [IN] 节点路径（例如：faceDetResult/faceInfo/0/objId）
 * @param ... 
 * @return RockIvaRetCode 
 */
RockIvaRetCode ROCKIVA_ONE_GetInt(const char* jsonStr, int* value, int defVal, const char* keyPathFmt, ...);

/**
 * @brief 获取float类型数据
 * 
 * @param jsonStr [IN] 结果json字符串
 * @param value [OUT] 结果值
 * @param defVal [IN] 默认值
 * @param keyPathFmt [IN] 节点路径（例如：faceDetResult/faceInfo/0/objId）
 * @param ... 
 * @return RockIvaRetCode 
 */
RockIvaRetCode ROCKIVA_ONE_GetFloat(const char* jsonStr, float* value, float defVal, const char* keyPathFmt, ...);

/**
 * @brief 获取字符串/字节数据
 * 
 * @param jsonStr [IN] 结果json字符串
 * @param data [OUT] 结果存放buffer
 * @param maxSize [IN] buffer大小
 * @param keyPathFmt [IN] 节点路径（例如：faceDetResult/faceInfo/0/objId）
 * @param ... 
 * @return RockIvaRetCode 
 */
RockIvaRetCode ROCKIVA_ONE_GetStr(const char* jsonStr, char* data, int maxSize, const char* keyPathFmt, ...);

/**
 * @brief 获取指针值
 * 
 * @param jsonStr [IN] 结果json字符串
 * @param ptr [OUT] 指针
 * @param keyPathFmt [IN] 节点路径（例如：faceDetResult/faceInfo/0/objId）
 * @param ... 
 * @return RockIvaRetCode 
 */
RockIvaRetCode ROCKIVA_ONE_GetPtr(const char* jsonStr, void** ptr, const char* keyPathFmt, ...);

/**
 * @brief 获取图像
 * 
 * @param jsonStr [IN] 结果json字符串
 * @param image [OUT] 图像
 * @param keyPathFmt [IN] 节点路径（例如：faceDetResult/faceInfo/0/objId）
 * @param ... 
 * @return RockIvaRetCode 
 */
RockIvaRetCode ROCKIVA_ONE_GetImage(const char* jsonStr, RockIvaImage* image, const char* keyPathFmt, ...);

/**
 * @brief 获取RockIvaRectangle对象数据
 * 
 * @param jsonStr [IN] 结果json字符串
 * @param rect [OUT] RockIvaRectangle对象数据
 * @param keyPathFmt [IN] 节点路径（例如：faceDetResult/faceInfo/0/objId）
 * @param ... 
 * @return RockIvaRetCode 
 */
RockIvaRetCode ROCKIVA_ONE_GetRect(const char* jsonStr, RockIvaRectangle* rect, const char* keyPathFmt, ...);

/**
 * @brief 获取数组元素个数
 * 
 * @param jsonStr [IN] 结果json字符串
 * @param size [OUT] 数组元素个数
 * @param keyPathFmt [IN] 节点路径（例如：faceDetResult/faceInfo/0/objId）
 * @param ... 
 * @return RockIvaRetCode 
 */
RockIvaRetCode ROCKIVA_ONE_GetArraySize(const char* jsonStr, int* size, const char* keyPathFmt, ...);

/**
 * @brief JSON的某个路径设置字符串
 * 
 * @param jsonStr [IN] json字符串
 * @param data [OUT] 字符串
 * @param maxSize [OUT] 字符串大小
 * @param keyPathFmt [IN] 节点路径（例如：faceDetResult/faceInfo/0/objId）
 * @param ... 
 * @return RockIvaRetCode 
 */
RockIvaRetCode ROCKIVA_ONE_SetStr(char* jsonStr, const char* data, int maxSize, const char* keyPathFmt, ...);

#ifdef __cplusplus
}
#endif /* end of __cplusplus */

#endif /* end of #ifndef __ROCKIVA_ONE_H__ */
