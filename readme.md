# 项目代码说明：

小规模联调仿真基于已知初始目标逻辑拓扑与初始物理拓扑，求解目标物理拓扑，并求解平滑重构阶段数.
python仿真文件：Test_data_7.py
matlab仿真文件：Test_data_7.m

大规模仿真基于随机生成初始目标逻辑拓扑与初始物理拓扑，求解目标逻辑拓扑，并求解平滑重构阶段数.
python仿真文件：test_data_for256_test.py
matlab仿真文件：test_data_for256_test.m

其中大规模仿真规模支持自定义修改输入结构体。

matlab仿真文件和python仿真文件在同输入下输出结果可能不同，这与算法无关，原因是python和matlab在执行同样操作时获得的输出不同，但是都是正确的

## 具体代码使用：

### 库函数要求

numpy, networkx， PyMaxflow

报  no module + 库函数名的错误解决方法：

调出 cmd，输入命令：
~~~
pip install + 库函数名
~~~

将 matlab / python 的所有文件放进同一文件夹，直接运行仿真文件即可

### 小规模代码运行：

Input： 

inputs 类：代表网络各项参数；

logical_topo 数组：代表各子逻辑拓扑

Logical_topo_desi 数组：代表目标逻辑拓扑

Output:

time：算法运行时间

stage：平滑重构阶段数

平滑重构各阶段动作

### 大规模代码运行：
Input：随机生成

Output:time、 stage、平滑重构各阶段动作

## 文件说明

matlab文件中和python同名的文件都是在仿真中会用到的，其他的matlab文件是一些子函数的旧版本，或是一些废弃的仿真文件，由于
后续可能会用到，因此没有被删除

### 函数接口

1. distr_Traffic.py and convert_inputs:

    用于修改已知信息，便于后续算法的调用

2. Input_class.py:

    用于存储所有函数需要使用的结构体以及其相关元素

3. generate_flows.py and generate_topo.py:

    用于产生流量需求和初始/目标逻辑拓扑

4. physical_topo_fu:

    用于计算目标物理拓扑，有多个子函数：
    
    a. cost_delconn_groom.py: 用于计算每个子拓扑的 metric
    
    b. re_add_conn.py：用于拓扑的打乱重连，包含子函数：sub_add_conns_v2.py，

    该子函数中还有 Beyond_Nodes.py、del_conns.py、max_flow.py、select_links.py 四个子函数

5. hitless_reconfig_v3.py:

    用于执行平滑重构算法

