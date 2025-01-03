--EXEC [dbo].[ReWeighingWeight_Delete] 1,207,28,3, 1, false
ALTER PROCEDURE [dbo].[ReWeighingWeight_Delete]
@IdCompany INT,
@IdReWeighingWeight INT,
@IdReWeighing INT,
@IdUserAud INT ,
@IdCompanyAud INT,
@FlagAll BIT
AS
BEGIN TRY
	DECLARE @TotalNet INT, @TotalNetLot INT,
	@BatchSize INT,
	@BatchSizeTolerance INT,
	@IdVehicle INT

	DECLARE @IdCompanyBranch INT
	SELECT 
	@IdCompanyBranch = IdCompanyBranch,
	@IdVehicle = IdVehicle
	FROM ReWeighingWeight WHERE IdCompany = @IdCompany AND IdReWeighingWeight = @IdReWeighingWeight	
	
	SELECT
	@BatchSize = ISNULL([BatchSize], 0),
	@BatchSizeTolerance = ISNULL(BatchSizeTolerance, 0)
	FROM ReWeighing WHERE IdCompany = @IdCompany AND IdReWeighing = @IdReWeighing AND DeletedFlag = 0 
	
	IF (@FlagAll = 1)
	BEGIN
		UPDATE ReWeighingWeight SET
			DeletedFlag = 1,
			UpdatedIdCompany = @IdCompanyAud,
			UpdatedIdUser = @IdUserAud,
			UpdatedDate = dbo.FechaUTC(@IdCompany, @IdCompanyBranch)
		WHERE IdCompany = @IdCompany
		--AND IdReWeighingWeight = @IdReWeighingWeight 
		AND IdReWeighing = @IdReWeighing
		AND DeletedFlag = 0
		
		UPDATE ReWeighing_Batch SET
		LimitBatchSize = 0
		WHERE IdReWeighing = @IdReWeighing
	END
	ELSE
	BEGIN
		UPDATE dbo.ReWeighingWeight SET
			DeletedFlag = 1,
			UpdatedIdCompany = @IdCompanyAud,
			UpdatedIdUser = @IdUserAud,
			UpdatedDate = dbo.FechaUTC(@IdCompany, @IdCompanyBranch)
		WHERE IdCompany = @IdCompany
		AND IdReWeighingWeight = @IdReWeighingWeight 
		AND IdReWeighing = @IdReWeighing

		
	END
	
	SELECT @TotalNet=ISNULL(SUM(NetWeight),0) FROM ReWeighingWeight WHERE IdCompany = @IdCompany AND IdReWeighing = @IdReWeighing AND DeletedFlag = 0
	IF (@FlagAll = 0)
	BEGIN
		UPDATE ReWeighing_Batch SET
		LimitBatchSize = LimitBatchSize - @BatchSize
		WHERE IdReWeighing = @IdReWeighing
		AND LimitBatchSize > @TotalNet
	END

	UPDATE ReWeighing SET
	ReWeight = @TotalNet
	WHERE IdCompany = @IdCompany AND IdReWeighing = @IdReWeighing

	DECLARE @NewBatchSize INT = @BatchSize
	IF ((SELECT LimitBatchSize FROM dbo.ReWeighing_Batch WHERE IdReWeighing = @IdReWeighing) >= @BatchSize)
	BEGIN
		SELECT @NewBatchSize = LimitBatchSize FROM dbo.ReWeighing_Batch WHERE IdReWeighing = @IdReWeighing
	END
	DECLARE @MinBatch INT = @NewBatchSize - @BatchSizeTolerance
	DECLARE @MaxBatch INT = @NewBatchSize + @BatchSizeTolerance
	--SELECT @TotalNet, @MinBatch, @NewBatchSize, @MaxBatch
	IF (@TotalNet BETWEEN @MinBatch AND @MaxBatch)
	BEGIN
		UPDATE dbo.MasterTable
		SET Valor = 4
		WHERE IdTable = 54
		AND IdColumn = 3
		
		UPDATE dbo.ReWeightVehicleCardId
		SET TareFlag = 0
		WHERE IdReWeighing = @IdReWeighing
		AND IdVehicle = @IdVehicle
		AND DeletedFlag = 0
	END
	ELSE IF (@TotalNet > @MaxBatch)
	BEGIN
		UPDATE dbo.MasterTable
		SET Valor = 5
		WHERE IdTable = 54
		AND IdColumn = 3

		UPDATE dbo.ReWeighing_Batch
		SET LimitBatchSize = @NewBatchSize + @BatchSize
		WHERE IdReWeighing = @IdReWeighing
		
		UPDATE dbo.ReWeightVehicleCardId
		SET TareFlag = 1
		WHERE IdReWeighing = @IdReWeighing
		AND IdVehicle = @IdVehicle
		AND DeletedFlag = 0
	END
	ELSE
	BEGIN
		UPDATE dbo.MasterTable
		SET Valor = 1
		WHERE IdTable = 54
		AND IdColumn = 3

		IF (SELECT 1 FROM dbo.ReWeighingWeight 
					WHERE IdCompany = @IdCompany 
					AND IdCompanyBranch = @IdCompanyBranch 
					AND IdReWeighing = @IdReWeighing 
					AND IdReWeighingWeight = @IdReWeighingWeight
					AND GrossWeight = 0) = 1
		BEGIN
			UPDATE dbo.ReWeightVehicleCardId
			SET TareFlag = 1
			WHERE IdReWeighing = @IdReWeighing
			AND IdVehicle = @IdVehicle
			AND DeletedFlag = 0
		END
	END

	SELECT 1 AS Ok, '' AS [Message]
END TRY
BEGIN CATCH
    SELECT 0 AS Ok, CONCAT('Línea N°', ERROR_LINE(), ': ', ERROR_MESSAGE()) AS [Message]
END CATCH
