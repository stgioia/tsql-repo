--https://straightforwardsql.com/posts/investigating-errors-with-extended-events/

CREATE EVENT SESSION [Error_reported] ON SERVER
ADD EVENT sqlserver.error_reported
(
    ACTION
    (
          sqlserver.server_instance_name   /* good practice for multi server querying */
        , sqlserver.client_app_name        /* helps locate the calling app */
        , sqlserver.client_hostname        /* calling computer name */
        , sqlserver.server_principal_name  /* can be switched to a user */
        , sqlserver.database_id            /* can be switched to a database_name */
        , sqlserver.sql_text               /* grab calling parameters from input buffer */
        , sqlserver.tsql_stack             /* get the whole stack for parsing later */
    )
    WHERE
    (
        severity > 10
        /* Please test and provide additional filters! */
    )
)
ADD TARGET
    package0.event_file
    (
        SET
            filename=N'Error_reported'
            , max_file_size= 20 /* MB */
    )


ALTER EVENT SESSION Error_reported ON SERVER STATE = Start /* Stop */


/*

-- Parse the XML output
DECLARE @stackOrFrame xml = 'Paste the <frames></frames> here'

;WITH
xmlShred AS
(
    SELECT
        COALESCE
        (
            CONVERT(varbinary(64), f.n.value('.[1]/@handle', 'varchar(max)'), 1),
            CONVERT(varbinary(64), f.n.value('.[1]/@sqlhandle', 'varchar(max)'), 1)
        ) AS handle,
        COALESCE
        (
            f.n.value('.[1]/@offsetStart', 'int'),
            f.n.value('.[1]/@stmtstart', 'int')
        ) AS offsetStart,
        COALESCE
        (
            f.n.value('.[1]/@offsetEnd', 'int'),
            f.n.value('.[1]/@stmtend', 'int')
        ) AS offsetEnd,
        f.n.value('.[1]/@line', 'int') AS line,
        f.n.value('.[1]/@level', 'tinyint') AS stackLevel
    FROM @stackOrFrame.nodes('//frame') AS f(n)
)
SELECT
    xs.stackLevel,
    ca.outerText,
    ca2.statementText
FROM
    xmlShred AS xs
    CROSS APPLY sys.dm_exec_sql_text(xs.handle) AS dest
    CROSS APPLY (SELECT LTRIM(RTRIM(dest.text))  FOR XML PATH(''), TYPE) AS ca(outerText)
    CROSS APPLY
    (
        SELECT
            SUBSTRING
            (
                dest.text,
                (xs.offsetStart / 2) + 1,
                ((
                    CASE
                        WHEN xs.offsetEnd = -1
                            THEN DATALENGTH(dest.text)
                        ELSE xs.offsetEnd
                    END
                    - xs.offsetStart
                ) / 2) + 1
            )
        FOR XML PATH(''), TYPE
    ) AS ca2(statementText)
ORDER BY xs.stackLevel
OPTION (RECOMPILE);

*/