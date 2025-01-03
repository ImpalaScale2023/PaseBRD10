--EXEC [dbo].[ReWighing_GetByCardId] 1, 1, 'C_0001'
ALTER PROCEDURE [dbo].[ReWighing_GetByCardId]
@IdCompany INT,
@IdCompanyBranch INT,
@CodCardId VARCHAR(30)
AS
BEGIN
DECLARE @Id INT = 0
SELECT 
@Id = rwcc.IdReWeightVehicleCardId 
FROM dbo.ReWeightVehicleCardId rwcc
INNER JOIN dbo.CardId ca ON rwcc.IdCardId = ca.IdCard
										AND ca.IdCompany = rwcc.IdCompany 
										AND ca.IdCompanyBranch = rwcc.IdCompanyBranch
										AND ca.DeletedFlag = 0
			WHERE rwcc.IdCompany = @IdCompany
			AND rwcc.IdCompanyBranch = @IdCompanyBranch
			AND ca.CodCard = @CodCardId
			AND rwcc.DeletedFlag = 0
			AND rwcc.IdStatusWeigh = 1
--SELECT @Id
IF @Id > 0
BEGIN
	SELECT CAST(1 AS BIT) AS Ok, '' AS [Message]

	UPDATE dbo.ReWeightVehicleCardId
	SET IdStatusWeigh = 2
	WHERE IdReWeightVehicleCardId = @Id

	UPDATE dbo.ReWeightVehicleCardId
	SET IdStatusWeigh = 1
	WHERE IdReWeightVehicleCardId <> @Id
			
	UPDATE dbo.MasterTable
	SET Valor =
		CASE IdColumn
			WHEN 1 THEN 2
			WHEN 2 THEN 5
			--WHEN 3 THEN 2
			--ELSE Valor
		END
	WHERE IdTable = 54
	AND IdColumn IN (1, 2);
END
ELSE
BEGIN
	UPDATE dbo.ReWeightVehicleCardId
	SET IdStatusWeigh = 1

	UPDATE dbo.MasterTable
	SET Valor =
		CASE IdColumn
			WHEN 1 THEN 4
			WHEN 2 THEN 1
			--WHEN 3 THEN 1
			--ELSE Valor
		END
	WHERE IdTable = 54
	AND IdColumn IN (1, 2);

	SELECT CAST(0 AS BIT) AS Ok, 'Card ID no encontrado' AS [Message]
END
END
