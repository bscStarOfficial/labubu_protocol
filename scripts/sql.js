const mysql = require("mysql");
const mysql_config = {
    // 开发环境
    host: "localhost",
    user: "root",
    password: "root",
    database: "bscStar",
    port: 3306
};
let pool = mysql.createPool({
    host: mysql_config.host,
    user: mysql_config.user,
    password: mysql_config.password,
    database: mysql_config.database,
    port: mysql_config.port
});

module.exports = {
    query(sql, options) {
        return new Promise(function (resolve, reject) {
            pool.getConnection(function (err, conn) {
                if (err) {
                    console.log(err)
                    reject("connect database fail");
                } else {
                    conn.query(sql, options, function (err, results, fields) {
                        //释放连接
                        conn.release();
                        //事件驱动回调
                        if (err) {
                            console.log(sql)
                            reject(err);
                        } else {
                            resolve(results, fields);
                        }
                    });
                }
            });
        });
    },

    update_sql_splice(sql, fields) {
        if (sql.substr(-1) === " ") {
            sql += `${fields} = ?`;
        } else {
            sql += `,${fields} = ?`;
        }
        return sql;
    },

    limit(sql, condition, pre) {
        if (condition.pageNo && condition.pageSize) {
            sql += ` limit ?,?`;
            pre.push((condition.pageNo - 1) * condition.pageSize)
            pre.push(parseInt(condition.pageSize))
        }

        return {
            "sql": sql,
            "pre": pre
        };
    },

    by(sql, by) {
        if (by.groupBy !== undefined) {
            sql += ` group by ${by.groupBy.k}`;
        }
        if (by.orderBy !== undefined) {
            sql += ` order by ${by.orderBy.k} ${by.orderBy.v}`;
        }

        return sql
    },

    transactionStart() {
        return new Promise((resolve, reject) => {
            pool.getConnection((err1, conn) => {
                if (err1) {
                    reject("connect database fail");
                } else {
                    conn.beginTransaction((err2) => {
                        if (err2) {
                            reject("transaction init error");
                        }
                        resolve(conn);
                    });
                }
            });
        });
    },

    connRollback(conn) {
        return new Promise((resolve, reject) => {
            conn.rollback(() => {
                conn.release();
                resolve();
            });
        });

    },

    connCommit(conn) {
        return new Promise((resolve, reject) => {
            conn.commit((err) => {
                if (err) {
                    conn.rollback(() => {
                        console.log('rollback --> ' + err.toString());
                        conn.release();
                        resolve();
                    });
                } else {
                    conn.release();
                    resolve();
                }

            });
        });
    },

    execute({conn, sql, pre}) {
        return new Promise((resolve, reject) => {
            conn.query(sql, pre, function (err, result) {
                if (err) {
                    console.log("sql:" + sql + "  pre" + JSON.stringify(pre));
                    reject(err);
                } else {
                    resolve(result);
                }
            })
        })
    },

};
