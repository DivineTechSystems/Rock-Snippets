/*
 delete-page.sql
 ===============
 Author:      Steven Floyd <DTS>

 Deletes a RockRMS page and all of its relationships, including:
 - Child pages (recursively)
 - Page routes
 - Page contexts
 - Blocks on each page
 - Block attribute values
 - Block HTML content
 - Page attribute values
 - Auth records for pages and blocks

 Usage:
 Set @PageId to the root page you want to delete.
 Run the SELECT at the bottom first (with the DELETEs commented out) to preview what will be removed.

 WARNING: This is extremely destructive! KNOW what you are doing with this.
 */ DECLARE @PageId INT = 0;

-- ============================================================================
-- 1. Gather all page Ids (the target page + all descendants)
-- ============================================================================
WITH PageHierarchy AS
  (SELECT [Id]
   FROM [Page]
   WHERE [Id] = @PageId
   UNION ALL SELECT p.[Id]
   FROM [Page] p
   INNER JOIN PageHierarchy ph ON p.[ParentPageId] = ph.[Id])
SELECT [Id] INTO #PagesToDelete
FROM PageHierarchy;

-- ============================================================================
-- 2. Gather all Block Ids on those pages
-- ============================================================================

SELECT b.[Id] INTO #BlocksToDelete
FROM [Block] b
WHERE b.[PageId] IN
    (SELECT [Id]
     FROM #PagesToDelete);

-- ============================================================================
-- 3. Preview what will be deleted
-- ============================================================================

SELECT 'Pages to delete' AS [Category],
       COUNT(*) AS [Count]
FROM #PagesToDelete
UNION ALL
SELECT 'Blocks to delete',
       COUNT(*)
FROM #BlocksToDelete
UNION ALL
SELECT 'HtmlContent records',
       COUNT(*)
FROM [HtmlContent]
WHERE [BlockId] IN
    (SELECT [Id]
     FROM #BlocksToDelete)
UNION ALL
SELECT 'Block AttributeValues',
       COUNT(*)
FROM [AttributeValue] av
INNER JOIN [Attribute] a ON a.[Id] = av.[AttributeId]
INNER JOIN [EntityType] et ON et.[Id] = a.[EntityTypeId]
WHERE et.[Name] = 'Rock.Model.Block'
  AND av.[EntityId] IN
    (SELECT [Id]
     FROM #BlocksToDelete)
UNION ALL
SELECT 'Page AttributeValues',
       COUNT(*)
FROM [AttributeValue] av
INNER JOIN [Attribute] a ON a.[Id] = av.[AttributeId]
INNER JOIN [EntityType] et ON et.[Id] = a.[EntityTypeId]
WHERE et.[Name] = 'Rock.Model.Page'
  AND av.[EntityId] IN
    (SELECT [Id]
     FROM #PagesToDelete)
UNION ALL
SELECT 'PageRoutes',
       COUNT(*)
FROM [PageRoute]
WHERE [PageId] IN
    (SELECT [Id]
     FROM #PagesToDelete)
UNION ALL
SELECT 'PageContexts',
       COUNT(*)
FROM [PageContext]
WHERE [PageId] IN
    (SELECT [Id]
     FROM #PagesToDelete)
UNION ALL
SELECT 'Auth (Page)',
       COUNT(*)
FROM [Auth]
WHERE [EntityTypeId] =
    (SELECT [Id]
     FROM [EntityType]
     WHERE [Name] = 'Rock.Model.Page')
  AND [EntityId] IN
    (SELECT [Id]
     FROM #PagesToDelete)
UNION ALL
SELECT 'Auth (Block)',
       COUNT(*)
FROM [Auth]
WHERE [EntityTypeId] =
    (SELECT [Id]
     FROM [EntityType]
     WHERE [Name] = 'Rock.Model.Block')
  AND [EntityId] IN
    (SELECT [Id]
     FROM #BlocksToDelete);

-- List the actual pages that will be removed

SELECT p.[Id],
       p.[InternalName],
       p.[ParentPageId],
       p.[Guid]
FROM [Page] p
WHERE p.[Id] IN
    (SELECT [Id]
     FROM #PagesToDelete)
ORDER BY p.[Id];

-- ============================================================================
-- 4. DELETE everything (uncomment this section when ready to execute)
-- ============================================================================
/*
BEGIN TRANSACTION;

-- 4a. Delete HtmlContent for blocks on these pages

DELETE
FROM [HtmlContent]
WHERE [BlockId] IN
    (SELECT [Id]
     FROM #BlocksToDelete);

-- 4b. Delete Auth records for blocks

DELETE
FROM [Auth]
WHERE [EntityTypeId] =
    (SELECT [Id]
     FROM [EntityType]
     WHERE [Name] = 'Rock.Model.Block')
  AND [EntityId] IN
    (SELECT [Id]
     FROM #BlocksToDelete);

-- 4c. Delete Block AttributeValues

DELETE
FROM [AttributeValue]
WHERE [AttributeId] IN
    (SELECT a.[Id]
     FROM [Attribute] a
     INNER JOIN [EntityType] et ON et.[Id] = a.[EntityTypeId]
     WHERE et.[Name] = 'Rock.Model.Block')
  AND [EntityId] IN
    (SELECT [Id]
     FROM #BlocksToDelete);

-- 4d. Delete Blocks

DELETE
FROM [Block]
WHERE [Id] IN
    (SELECT [Id]
     FROM #BlocksToDelete);

-- 4e. Delete Auth records for pages

DELETE
FROM [Auth]
WHERE [EntityTypeId] =
    (SELECT [Id]
     FROM [EntityType]
     WHERE [Name] = 'Rock.Model.Page')
  AND [EntityId] IN
    (SELECT [Id]
     FROM #PagesToDelete);

-- 4f. Delete Page AttributeValues

DELETE
FROM [AttributeValue]
WHERE [AttributeId] IN
    (SELECT a.[Id]
     FROM [Attribute] a
     INNER JOIN [EntityType] et ON et.[Id] = a.[EntityTypeId]
     WHERE et.[Name] = 'Rock.Model.Page')
  AND [EntityId] IN
    (SELECT [Id]
     FROM #PagesToDelete);

-- 4g. Delete PageContexts

DELETE
FROM [PageContext]
WHERE [PageId] IN
    (SELECT [Id]
     FROM #PagesToDelete);

-- 4h. Delete PageRoutes

DELETE
FROM [PageRoute]
WHERE [PageId] IN
    (SELECT [Id]
     FROM #PagesToDelete);

-- 4i. NULL out Site FK references to these pages
UPDATE [Site] SET [LoginPageId] = NULL WHERE [LoginPageId] IN (SELECT [Id] FROM #PagesToDelete);
UPDATE [Site] SET [LoginPageRouteId] = NULL WHERE [LoginPageRouteId] IN (SELECT [Id] FROM [PageRoute] WHERE [PageId] IN (SELECT [Id] FROM #PagesToDelete));
UPDATE [Site] SET [ChangePasswordPageId] = NULL WHERE [ChangePasswordPageId] IN (SELECT [Id] FROM #PagesToDelete);
UPDATE [Site] SET [ChangePasswordPageRouteId] = NULL WHERE [ChangePasswordPageRouteId] IN (SELECT [Id] FROM [PageRoute] WHERE [PageId] IN (SELECT [Id] FROM #PagesToDelete));
UPDATE [Site] SET [RegistrationPageId] = NULL WHERE [RegistrationPageId] IN (SELECT [Id] FROM #PagesToDelete);
UPDATE [Site] SET [RegistrationPageRouteId] = NULL WHERE [RegistrationPageRouteId] IN (SELECT [Id] FROM [PageRoute] WHERE [PageId] IN (SELECT [Id] FROM #PagesToDelete));
UPDATE [Site] SET [PageNotFoundPageId] = NULL WHERE [PageNotFoundPageId] IN (SELECT [Id] FROM #PagesToDelete);
UPDATE [Site] SET [PageNotFoundPageRouteId] = NULL WHERE [PageNotFoundPageRouteId] IN (SELECT [Id] FROM [PageRoute] WHERE [PageId] IN (SELECT [Id] FROM #PagesToDelete));
UPDATE [Site] SET [DefaultPageId] = NULL WHERE [DefaultPageId] IN (SELECT [Id] FROM #PagesToDelete);
UPDATE [Site] SET [DefaultPageRouteId] = NULL WHERE [DefaultPageRouteId] IN (SELECT [Id] FROM [PageRoute] WHERE [PageId] IN (SELECT [Id] FROM #PagesToDelete));
UPDATE [Site] SET [CommunicationPageId] = NULL WHERE [CommunicationPageId] IN (SELECT [Id] FROM #PagesToDelete);
UPDATE [Site] SET [CommunicationPageRouteId] = NULL WHERE [CommunicationPageRouteId] IN (SELECT [Id] FROM [PageRoute] WHERE [PageId] IN (SELECT [Id] FROM #PagesToDelete));

-- 4j. Delete Pages (children first — delete deepest descendants before parents)
 -- Using a loop to respect the ParentPageId foreign key
 WHILE EXISTS
  (SELECT 1
   FROM #PagesToDelete) BEGIN -- Delete leaf pages (pages whose Id is not a parent of any remaining page)

DELETE
FROM [Page]
WHERE [Id] IN
    (SELECT ptd.[Id]
     FROM #PagesToDelete ptd
     WHERE NOT EXISTS
         (SELECT 1
          FROM [Page] p2
          WHERE p2.[ParentPageId] = ptd.[Id]));

-- Remove those from our tracking table too

DELETE
FROM #PagesToDelete
WHERE [Id] NOT IN
    (SELECT [Id]
     FROM [Page]
     WHERE [Id] IN
         (SELECT [Id]
          FROM #PagesToDelete));
END;

COMMIT TRANSACTION;
 -- If something goes wrong, use: ROLLBACK TRANSACTION;
 */ -- ============================================================================
-- 5. Cleanup temp tables
-- ============================================================================

DROP TABLE IF EXISTS #PagesToDelete;


DROP TABLE IF EXISTS #BlocksToDelete;
