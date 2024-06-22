import numpy as np
import copy


def ismember_rows(A, B):
    # 将每一行的数据转换为元组，以便进行集合比较
    A_tuples = {tuple(row) for row in A}
    B_tuples = {tuple(row) for row in B}

    # 创建布尔数组，表示 A 中的每一行是否存在于 B 中
    is_member = np.array([row in B_tuples for row in A])

    # 获取在 B 中的行的索引
    indexes = np.where(is_member)[0]

    return is_member, indexes


def target_topo_convert(S_Conn_cap, S, logical_topo, update_logical_topo, port_allocation_inti_topo, inputs):
    S_Conn_cap_1 = copy.deepcopy(S_Conn_cap)
    port_allocation_inti_topo1 = copy.deepcopy(port_allocation_inti_topo)
    E1 = copy.deepcopy(S)
    T = inputs.groupnum
    K = inputs.oxcnum_agroup
    method = inputs.method
    sum_row = np.zeros([T, K, inputs.nodes_num])
    sum_col = np.zeros([T, K, inputs.nodes_num])
    del_logical_topo = np.empty((T, K), dtype=object)
    add_logical_topo = np.empty((T, K), dtype=object)
    for t in range(0, T):
        for k in range(0, K):
            for de in range(0, inputs.nodes_num):
                sum_row[t, k, de] = np.sum(update_logical_topo[t, k], axis=1)[de]
                sum_col[t, k, de] = np.sum(update_logical_topo[t, k], axis=0)[de]
                checkdebug = 1

            del_logical_topo[t, k] = logical_topo[t, k] - update_logical_topo[t, k]
            del_logical_topo[t, k][del_logical_topo[t, k] < 0] = 0
            add_logical_topo[t, k] = update_logical_topo[t, k] - logical_topo[t, k]
            add_logical_topo[t, k][add_logical_topo[t, k] < 0] = 0

            conn_row, conn_col = np.triu_indices(del_logical_topo[t, k])
            conn_row = conn_row[conn_row != 0]
            conn_col = conn_col[conn_col != 0]
            for conn_ind in range(0, len(conn_row)):
                zero_rows = np.all(S_Conn_cap_1[:, 4:5] == 0, axis=1)
                S_Conn_cap_1 = S_Conn_cap_1[zero_rows, :]

                lia, lobc = ismember_rows(S_Conn_cap_1[:, 0:1], [conn_row[conn_ind], conn_col[conn_ind]])
                conn_row_ind = np.where(lia != 0)[0]
                pods_port_cap = S_Conn_cap_1[conn_row_ind, 6]

                if method == 2 or method == 3:
                    sorted_pods_port_cap, sorted_port_cap_ind = np.sort(pods_port_cap)[::-1]
                else:
                    sorted_pods_port_cap, sorted_port_cap_ind = np.sort(pods_port_cap)

                sorted_ports = S_Conn_cap_1[conn_row_ind[sorted_port_cap_ind], :]
                lia_group, _ = ismember_rows(sorted_ports[:, 3:4], [t, k])
                group_row = np.where(lia_group != 0)[0]
                sorted_ports1 = sorted_ports[group_row, :]

                used_ports_num = del_logical_topo[conn_row[conn_ind], conn_col[conn_ind]]
                used_index = np.where(lia_group == used_ports_num)[0]
                S_conn_cap_sortind = conn_row_ind[sorted_port_cap_ind]
                used_ports_loc = S_conn_cap_sortind[used_index]
                S_Conn_cap_1[used_ports_loc, 4:6] = 0

                for ii in range(0, del_logical_topo[t, k](conn_row(conn_ind),conn_col(conn_ind))):
                    E1[sorted_ports1[ii, 4], sorted_ports1[ii, 5], k, t] = 0
                    E1[sorted_ports1[ii, 5], sorted_ports1[ii, 4], k, t] = 0

                    port_allocation_inti_topo[t, 0][k, 0][0, sorted_ports1[ii, 4]] = conn_row[conn_ind]
                    port_allocation_inti_topo[t, 0][k, 0][0, sorted_ports1[ii, 5]] = conn_col[conn_ind]

            [conn_row, conn_col] = np.triu_indices(add_logical_topo)
            conn_row = conn_row[conn_row != 0]
            conn_col = conn_col[conn_col != 0]
            for conn_ind in range(0, len(conn_row)):
                _, poducol = np.where(port_allocation_inti_topo[t, 0][k, 0][0, :] == conn_row[conn_ind])
                _, podvcol = np.where(port_allocation_inti_topo[t, 0][k, 0][0, :] == conn_col[conn_ind])

                for ii in range(0, add_logical_topo[t, k][conn_row[conn_ind], conn_col[conn_ind]]):
                    E1[poducol[ii], podvcol[ii], k, t] = 1
                    E1[podvcol[ii], poducol[ii], k, t] = 1

                    port_allocation_inti_topo[t, 0][k, 0][0, poducol[ii]] = 0
                    port_allocation_inti_topo[t, 0][k, 0][0, podvcol[ii]] = 0

    return E1
