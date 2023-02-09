SELECT top 10 UserName, *
  FROM [SnowInventory].[inv].DataClient
  with (nolock)
  where hostname = 'X'