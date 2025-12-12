#!/usr/bin/env sysbench

-- Parâmetros (herdados do sysbench)
sysbench.cmdline.options = {
  tables = {"Number of tables", 1},
  table_size = {"Number of rows per table", 10000},
  create_secondary = {"Create a secondary index", true}
}

-- Função para criar a tabela
function create_table(conn, table_num)
  local tbl_name = "sbtest" .. table_num
  print("Creating table " .. tbl_name)
  conn:query("DROP TABLE IF EXISTS " .. tbl_name)
  conn:query([[
    CREATE TABLE ]] .. tbl_name .. [[ (
      id INTEGER NOT NULL,
      k INTEGER DEFAULT '0' NOT NULL,
      c CHAR(120) DEFAULT '' NOT NULL,
      pad CHAR(60) DEFAULT '' NOT NULL,
      PRIMARY KEY (id)
    ) ENGINE=InnoDB
  ]])

  if sysbench.opt.create_secondary then
    conn:query("CREATE INDEX k_" .. table_num .. " ON " .. tbl_name .. " (k)")
  end
end

-- Função para popular a tabela — UM INSERT POR LINHA
function prepare()
  local t = sysbench.sql.Connection()
  t:connect()

  for i = 1, sysbench.opt.tables do
    create_table(t, i)

    print("Populating table sbtest" .. i)

    local batch_size = 1000
    t:query("START TRANSACTION")

    for j = 1, sysbench.opt.table_size do
      local k = sb_rand(1, sysbench.opt.table_size)
      local c = sb_rand_str("###########-###########-###########-###########")
      local pad = sb_rand_str("###########-###########-###########-###########")

      -- Monta e executa o INSERT (um por linha)
      t:query(string.format(
        "INSERT INTO sbtest%d (id, k, c, pad) VALUES (%d, %d, '%s', '%s')",
        i, j, k, c, pad
      ))

      -- Commit a cada `batch_size` linhas
      if j % batch_size == 0 then
        t:query("COMMIT")
        if j < sysbench.opt.table_size then
          t:query("START TRANSACTION")
        end
      end
    end

    -- Commit final, caso reste alguma linha sem commit
    if sysbench.opt.table_size % batch_size ~= 0 then
      t:query("COMMIT")
    end
  end

  t:disconnect()
end

-- Para rodar o benchmark (opcional, se quiser usar também no run)
function event()
  -- Opcional: reutilize o original ou deixe vazio se só quiser o prepare
  error("Este script é apenas para 'prepare'. Use oltp_read_write.lua para o benchmark em si.")
end