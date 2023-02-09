--https://www.sqlservercentral.com/blogs/my-alternative-to-sp_whoisactive
SELECT s.session_id, 
r.start_time, 
s.host_name, 
s.login_name,
i.event_info,
r.status,
s.program_name,
r.writes,
r.reads,
r.logical_reads,
r.blocking_session_id,
r.wait_type,
r.wait_time,
r.wait_resource
FROM sys.dm_exec_requests as r
JOIN sys.dm_exec_sessions as s
 on s.session_id = r.session_id
CROSS APPLY sys.dm_exec_input_buffer(s.session_id, r.request_id) as i
WHERE s.session_id != @@SPID
and s.is_user_process = 1 