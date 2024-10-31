ALTER TABLE dbo.Bascule
ADD FlagCardReader BIT

GO

-- dbo.Bascule_Update_FlagCardReader 1, 1, 3, false, 1
CREATE PROCEDURE dbo.Bascule_Update_FlagCardReader
@IdCompany INT,
@IdCompanyBranch INT,
@IdBascule INT,
@FlagCardReader BIT,
@IdType INT -- 1: Invocado desde el Sistema Web, 2: Windows Service
AS
BEGIN TRY

IF @IdType = 2
BEGIN
	UPDATE dbo.Bascule SET
	FlagCardReader = @FlagCardReader
	WHERE IdCompany = @IdCompany
	AND IdCompanyBranch = @IdCompanyBranch
	AND IdBascule = @IdBascule
END

SELECT 
0 AS Code,
ISNULL(FlagCardReader, 0) AS FlagCardReader,
'asd' AS [Message]
FROM dbo.Bascule 
WHERE IdCompany = @IdCompany
AND IdCompanyBranch = @IdCompanyBranch
AND IdBascule = @IdBascule

END TRY
BEGIN CATCH
    ROLLBACK TRAN
	SELECT 
	1 AS Code,
	CAST(0 AS BIT) AS FlagCardReader,
	CONCAT('Línea N°', ERROR_LINE(), ': ', ERROR_MESSAGE()) AS [Message]
END CATCH
