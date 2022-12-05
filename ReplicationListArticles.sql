--https://sqlstudies.com/2022/05/17/getting-a-list-of-the-articles-in-a-publication/
USE publisherDB; /* This is the database where the publication exists. */
SELECT 
    DB_Name() PublicationDB 
    , sp.name AS PublicationName
    , sp.status AS PublicationActive
    , sa.name AS ArticleName 
    , o.name AS ObjectName
    , srv.srvname AS SubscriberServerName 
    , s.dest_db AS SubscriberDBName
FROM dbo.syspublications sp  
JOIN dbo.sysarticles sa ON sp.pubid = sa.pubid 
LEFT OUTER JOIN dbo.syssubscriptions s ON sa.artid = s.artid 
LEFT OUTER JOIN master.dbo.sysservers srv ON s.srvid = srv.srvid
JOIN sys.objects o ON sa.objid = o.object_id;


