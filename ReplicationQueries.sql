--undistributed commands
SELECT name, count (1)
FROM      distribution.dbo.MSdistribution_status ds (NOLOCK)
JOIN	distribution.dbo.MSdistribution_agents d (NOLOCK)
ON	ds.agent_id = d.id 
WHERE	d.subscriber_db not in ('virtual')
AND 	d.anonymous_subid	is null 
GROUP BY name

