## 介绍
使用glsl实现简单的光线追踪。

## 特征
* 散射，镜面反射，折射
* 三角形，球
* 多帧混合
* 光线追踪隐式曲面
* disney brdf
* 重要性采样
## 结果
![img](image/sphere.PNG)

![img](image/heart.PNG)

![img](image/metal.PNG)

## 参考
* https://blog.csdn.net/weixin_44176696/article/details/119044396
* https://github.com/knightcrawler25/GLSL-PathTracer
* Knoll A, Hijazi Y, Kensler A, et al. Fast ray tracing of arbitrary implicit surfaces with interval and affine arithmetic[C]//Computer Graphics Forum. Oxford, UK: Blackwell Publishing Ltd, 2009, 28(1): 26-40.
* https://github.com/wdas/brdf/blob/main/src/brdfs/disney.brdf

## 问题？
1. 从图像中心开始会出现波纹形状？
2. 隐式曲面法线精确计算？