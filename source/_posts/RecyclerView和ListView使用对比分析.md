---
title: RecyclerView和ListView使用对比分析
date: 2017-09-25 18:33:16
categories: Android
---
RecyclerView优点
1. 设置布局管理器可成为 线性布局、网格布局（GridView）、瀑布流布局
2. 自带动画效果，也可自定义动画
3. 自带局部更新
4. 支持嵌套滚动机制

ListView优点
1. 空数据处理 setEmptyView处理Adapter中数据为空的情况
2. 头布局和脚布局提供api直接添加
3. 拥有条目事件监听 onItemClickListener

性能分析：RecyclerView复用控件拥有更多缓存机制（4级缓存优化）
        ListView复用控件拥有2级缓存

目前使用BaseRecyclerViewAdapterHelper第三方开源库拥有ListView优点

refrence: https://www.jianshu.com/p/f592f3715ae2
&emsp;&emsp;&emsp;&emsp;&ensp;&ensp; https://zhuanlan.zhihu.com/p/23339185