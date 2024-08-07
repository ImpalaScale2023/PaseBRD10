--EXEC [dbo].[Driver_PopUp] 1, '', 1, 10
ALTER PROCEDURE [dbo].[Driver_PopUp]
@IdCompanyBranch INT,
@Search VARCHAR(200),
@PageIndex INT,
@PageSize INT
AS
SET NOCOUNT ON

--#Weighing
IF OBJECT_ID('tempdb.dbo.#Weighing') IS NOT NULL
BEGIN
  TRUNCATE TABLE dbo.#Weighing;
END
ELSE
BEGIN
	CREATE TABLE dbo.#Weighing(
		[Id] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY CLUSTERED,
		[IdCompany] [int] NOT NULL,
		[IdWeighing] [int] NOT NULL,
		[InputIdDriver] [int] NOT NULL,
	)

	CREATE NONCLUSTERED INDEX [IX_TmpWeighing_InputIdDriver] ON dbo.#Weighing
	(
		[IdCompany] ASC,
		[InputIdDriver] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]

END

INSERT INTO dbo.#Weighing (IdCompany, IdWeighing, InputIdDriver)
SELECT 
we.IdCompany,
we.IdWeighing,
we.InputIdDriver 
FROM dbo.Weighing we 
WHERE we.DeletedFlag = 0
AND (
	(we.IdStatus < 3 AND we.IdWeighingCycle = 1)
	OR
	(we.IdStatus < 2 AND we.IdWeighingCycle = 2)
)

IF OBJECT_ID('tempdb.dbo.#Driver') IS NOT NULL
BEGIN
  TRUNCATE TABLE dbo.#Driver;
END
ELSE
BEGIN
CREATE TABLE dbo.#Driver(
	[Id] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY CLUSTERED,
	[IdCompany] [int] NOT NULL,
	[IdDriver] [int] NOT NULL,
	)
END

INSERT INTO dbo.#Driver (IdCompany, IdDriver)
SELECT
dr.IdCompany,
dr.IdDriver
FROM Driver dr 
INNER JOIN MasterTable tblm ON tblm.IdTable = 1 AND tblm.IdColumn = dr.IdStatus AND tblm.IdColumn > 0
LEFT JOIN Country co ON co.IdCountry = dr.IdCountry
WHERE NOT EXISTS (SELECT 1 FROM dbo.#Weighing we 
			WHERE dr.IdCompany = we.IdCompany
				AND dr.IdDriver = we.InputIdDriver)
AND (
        dr.Driver LIKE '%' + @Search + '%' 
		OR co.IdCountry LIKE '%' + @Search + '%' 
		OR co.Country LIKE '%' + @Search + '%'
		OR dr.IdNumber LIKE '%' + @Search + '%' 
		OR dr.LicenseNumber LIKE '%' + @Search + '%'  
    )
AND dr.DeletedFlag = 0 
AND IdCompanyBranch = @IdCompanyBranch
ORDER BY dr.DriverName ASC

DECLARE @TotalElements INT = 0
 
SELECT @TotalElements = COUNT(1) FROM dbo.#Driver

SET NOCOUNT OFF

SELECT 
dr.IdDriver,
dr.Driver,
dr.IdCountry,
co.Country,
dr.IdNumber,
dr.LicenseNumber,
dr.IdStatus, 
tblm.[Description] AS [Status],
@TotalElements AS TotalElements
FROM dbo.#Driver tmdr
INNER JOIN Driver dr ON tmdr.IdCompany = dr.IdCompany AND tmdr.IdDriver = dr.IdDriver
INNER JOIN MasterTable tblm ON tblm.IdTable = 1 AND tblm.IdColumn = dr.IdStatus AND tblm.IdColumn > 0
LEFT JOIN Country co ON co.IdCountry = dr.IdCountry
ORDER BY dr.IdDriver ASC
OFFSET @PageSize * (@PageIndex - 1) ROWS
FETCH NEXT @PageSize ROWS ONLY