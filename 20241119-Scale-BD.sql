CREATE FUNCTION [dbo].[CustomCalculation] (@baseValue INT, @x INT)
RETURNS INT
AS
BEGIN
    DECLARE @result INT;

    IF @x < @baseValue
        SET @result = @baseValue - @x;
    ELSE
        SET @result = ABS(@baseValue - @x) / 2;

    RETURN @result;
END;

GO
-- [dbo].[ReWighing_TV_GetByBascule] 1, 1, 0, 3
ALTER PROCEDURE [dbo].[ReWighing_TV_GetByBascule]
@IdCompany INT,
@IdCompanyBranch INT,
@TimeZone INT,
@IdBascule INT
AS
DECLARE @Weight INT, 
@IdStatusRWW INT,  
@FlagLeer BIT,
@IdEstadoAutorizado INT,
@IdCapturaPeso INT,
@IdDireccion INT,
@WeightMinTare INT,
@CurrentLot INT,
@CurrentWeightLot INT

SELECT 
    @IdEstadoAutorizado = 
        CASE IdColumn
            WHEN 1 THEN Valor
            ELSE @IdEstadoAutorizado
        END,
    @IdCapturaPeso = 
        CASE IdColumn
            WHEN 2 THEN Valor
            ELSE 1
        END,
    @IdDireccion = 
        CASE IdColumn
            WHEN 3 THEN Valor
        END
FROM dbo.MasterTable
WHERE IdTable = 54
AND IdColumn IN (1, 2, 3);

SELECT @WeightMinTare = CONVERT(INT, Valor) FROM  dbo.MasterTable WHERE IdTable = 1000 AND IdColumn = 3

SELECT 
@Weight = Peso,
@FlagLeer = FlagLeer
FROM dbo.Bascule WHERE IdCompany = @IdCompany AND IdCompanyBranch = @IdCompanyBranch AND IdBascule = @IdBascule

SELECT
@IdEstadoAutorizado AS IdEstadoAutorizado,
@IdCapturaPeso AS IdCapturaPeso,
@IdDireccion AS IdDireccion,
rw.IdReWeighing,
rww.IdReWeighingWeight,
car.CodCard AS CardId,
rw.Pila AS Pila,
ve.IdVehicle,
ve.TruckNumber AS TruckPlate,
pr.DescProduct AS Product,
ve.TrailerNumber AS TrailerPlate,
qu.[Description] AS Quality,
rw.[Weight] AS InstructedWeight,
rw.ReWeight AS ReWeight,
rw.[Weight] - rw.ReWeight AS ToReWeigh,
rw.MaxWeighing AS Lotization,
rw.ReWeight AS Advance,
rw.LotTo AS LotToClose,
--rww.Lot AS LotToClose,
rw.MaxWeighing AS LotSize,
0 AS DesTare,
rwvc.IdStatusWeigh,
(ISNULL(ve.TruckTare, 0) + ISNULL(ve.TrailerTare, 0) - ISNULL(TruckTareTolerance, 0)) AS TareWeightMin,
(ISNULL(ve.TruckTare, 0) + ISNULL(ve.TrailerTare, 0) + ISNULL(TruckTareTolerance, 0)) AS GrossWeightMin,
IIF(ISNULL(rww.TareWeight, 0) = 0, 0, @Weight) AS GrossWeight,
IIF(ISNULL(rww.TareWeight, 0) = 0, @Weight, rww.TareWeight) AS TareWeight,
IIF(rww.TareWeight = 0, 0, @Weight - rww.TareWeight) AS NetWeight,
car.IdStatus, 
rw.IdStatus AS IdStatusRW,
rw.[BatchSize],
rw.BatchSizeTolerance,
(SELECT LimitBatchSize FROM dbo.ReWeighing_Batch rwb WHERE rwb.IdReWeighing = rw.IdReWeighing) AS BatchSizeAcumulate,
ISNULL(rwvc.TareFlag, 1) AS TareFlag
INTO #data
FROM dbo.ReWeightVehicleCardId rwvc
INNER JOIN dbo.CardId car ON car.IdCompany = rwvc.IdCompany AND car.IdCompanyBranch = rwvc.IdCompanyBranch AND car.IdCard = rwvc.IdCardId
INNER JOIN dbo.ReWeighing rw ON rwvc.IdReWeighing = rw.IdReWeighing AND rw.IdStatus IN (1, 2, 3)
INNER JOIN dbo.Product pr ON rw.IdProduct = pr.IdProduct
INNER JOIN dbo.Quality qu ON rw.IdQuality = qu.IdQuality
INNER JOIN dbo.Vehicle ve ON rwvc.IdVehicle = ve.IdVehicle 
							AND ve.IdCompany = rwvc.IdCompany 
							AND ve.IdCompanyBranch = rwvc.IdCompanyBranch
							AND ve.DeletedFlag = 0
LEFT JOIN dbo.ReWeighingWeight rww ON rww.IdVehicle = ve.IdVehicle AND rww.IdStatusWeight < 2 AND rww.DeletedFlag = 0 AND rww.IdReWeighing = rw.IdReWeighing
--LEFT JOIN dbo.ReWeighingWeight rww ON rww.IdVehicle = ve.IdVehicle AND rww.DeletedFlag = 0 AND rww.IdReWeighing = rw.IdReWeighing
WHERE rwvc.IdCompany = @IdCompany
AND rwvc.IdCompanyBranch = @IdCompanyBranch
AND rwvc.DeletedFlag = 0
AND rwvc.IdStatusWeigh = 2
--AND @FlagLeer = 1

IF (SELECT COUNT(1) FROM #data) > 0
BEGIN
	DECLARE @IdStatus INT, @IdStatusRW INT;
	SELECT @IdStatus = IdStatus, @IdStatusRW = IdStatusRW FROM #data
	IF @IdStatus = 1 AND @IdStatusRW < 3
	BEGIN
		DECLARE @TareWeight INT

		-- Validar bien esa parte
		SET @TareWeight = ISNULL((select top 1 rewe.TareWeight from ReWeighingWeight rewe
															INNER JOIN #data tmp ON tmp.IdReWeighing = rewe.IdReWeighing AND tmp.IdVehicle = rewe.IdVehicle
								where rewe.IdCompany = @IdCompany
								AND rewe.DeletedFlag = 0
								order by rewe.IdReWeighingWeight desc),0) 
		--SELECT @TareWeight
		SELECT @CurrentLot = MAX(rewe.Lot), @CurrentWeightLot = SUM(rewe.NetWeight)
		FROM dbo.ReWeighingWeight rewe
		INNER JOIN #data tmp ON tmp.IdReWeighing = rewe.IdReWeighing
		WHERE rewe.IdCompany = @IdCompany
		AND rewe.DeletedFlag = 0
		--ORDER BY rewe.IdReWeighingWeight desc
		GROUP BY rewe.Lot

		SELECT 
		--TOP(1)
		--@IdCapturaPeso = IIF((GrossWeight = 0 AND @TareWeight = 0), 
		--					IIF(TareWeight < ISNULL(TareWeightMin, @WeightMinTare), 5, 2), 
		--					IIF(IIF(TareFlag = 0, @Weight, TareWeight) > ISNULL(GrossWeightMin, TareWeight), 3, 4)),
		@IdCapturaPeso = IIF((TareFlag = 0 AND @TareWeight = 0 AND GrossWeight = 0) OR @IdDireccion = 5, 
						IIF(TareWeight <= IIF(TareWeightMin > @WeightMinTare, TareWeightMin, @WeightMinTare) OR TareWeight >= GrossWeightMin, 5, 2), 
						IIF(@Weight > ISNULL(GrossWeightMin, TareWeight), 3, 4)),
		@IdDireccion = IIF(GrossWeight = 0, 3, 2) -- 4, 5
		FROM #data

		--SELECT @TareWeight, ISNULL(GrossWeight, 0),  TareWeight, GrossWeightMin FROM #data
		--SELECT * FROM MasterTable WHERE IdTable = 53
		--SET @IdEstadoAutorizado = 2
		UPDATE dbo.MasterTable 
		SET Valor = @IdCapturaPeso
		WHERE IdTable = 54 
		AND IdColumn = 2

		--SELECT *, @TareWeight FROM #data
		
		SELECT
		TOP(1)
		ISNULL(da.IdReWeighingWeight, 0) AS IdReWeighingWeight,
		@IdEstadoAutorizado AS IdEstadoAutorizado,
		(SELECT [Description] FROM dbo.MasterTable WHERE IdTable = 51 AND IdColumn = @IdEstadoAutorizado) AS EstadoAutorizado,
		@IdCapturaPeso AS IdCapturaPeso,
		(SELECT [Description] FROM dbo.MasterTable WHERE IdTable = 52 AND IdColumn = @IdCapturaPeso) AS CapturaPeso,
		@IdDireccion AS IdDireccion,
		(SELECT [Description] FROM dbo.MasterTable WHERE IdTable = 53 AND IdColumn = @IdDireccion) AS Direccion,
		da.IdReWeighing,
		da.CardId,
		da.Pila,
		IIF(TareFlag = 0, ISNULL(da.TareWeight, 0), @TareWeight) AS TareWeight,
		da.IdVehicle,
		da.TruckPlate,
		da.Product,
		IIF(TareFlag = 0, 0, @Weight) AS GrossWeight,
		--ISNULL(da.GrossWeight, 0) AS GrossWeight,
		da.TrailerPlate,
		da.Quality,
		--ISNULL(da.GrossWeight, 0) - ISNULL(da.TareWeight, 0) AS NetWeight,
		IIF(TareFlag = 0, 0, @Weight - @TareWeight) AS NetWeight,
		da.InstructedWeight,
		da.ReWeight,
		da.ToReWeigh,
		da.Lotization,
		--(da.Advance + IIF(@TareWeight = 0, 0, @Weight - @TareWeight)) AS Advance,
		@CurrentWeightLot AS Advance,
		@CurrentLot AS LotToClose,
		da.LotSize,
		([BatchSize] - dbo.CustomCalculation([BatchSize], Advance)) AS DesTare,
		ISNULL(da.TareWeightMin, 0) AS TareWeightMin,
		ISNULL(da.GrossWeightMin, 0) AS GrossWeightMin,
		[BatchSize],
		BatchSizeTolerance,
		dbo.CustomCalculation([BatchSize], Advance) AS BatchSizeAcumulate,
		TareFlag
		FROM #data da
	END
	ELSE
	BEGIN
		SET @IdEstadoAutorizado = IIF(@IdStatusRW = 3, 5, 4)
		SELECT
		@IdEstadoAutorizado AS IdEstadoAutorizado,
		(SELECT [Description] FROM dbo.MasterTable WHERE IdTable = 51 AND IdColumn = @IdEstadoAutorizado) AS EstadoAutorizado,
		@IdCapturaPeso AS IdCapturaPeso,
		(SELECT [Description] FROM dbo.MasterTable WHERE IdTable = 52 AND IdColumn = @IdCapturaPeso) AS CapturaPeso,
		@IdDireccion AS IdDireccion,
		(SELECT [Description] FROM dbo.MasterTable WHERE IdTable = 53 AND IdColumn = @IdDireccion) AS Direccion,
		0 AS IdReWeighing,
		'-' AS CardId,
		'-' AS Pila,
		0 AS TareWeight,
		0 AS IdVehicle,
		'-' AS TruckPlate,
		'-' AS Product,
		0 AS GrossWeight,
		'-' AS TrailerPlate,
		'-' AS Quality,
		0 AS NetWeight,
		0 AS InstructedWeight,
		0 AS ReWeight,
		0 AS ToReWeigh,
		0 AS Lotization,
		0 AS Advance,
		0 AS LotToClose,
		0 AS LotSize,
		0 AS DesTare,
		0 AS TareWeightMin,
		0 AS GrossWeightMin,
		0 AS [BatchSize],
		0 AS BatchSizeTolerance,
		0 AS BatchSizeAcumulate,
		CAST(1 AS BIT) AS TareFlag
	END
END
ELSE
BEGIN
	SELECT
	@IdEstadoAutorizado AS IdEstadoAutorizado,
	(SELECT [Description] FROM dbo.MasterTable WHERE IdTable = 51 AND IdColumn = @IdEstadoAutorizado) AS EstadoAutorizado,
	@IdCapturaPeso AS IdCapturaPeso,
	(SELECT [Description] FROM dbo.MasterTable WHERE IdTable = 52 AND IdColumn = @IdCapturaPeso) AS CapturaPeso,
	@IdDireccion AS IdDireccion,
	(SELECT [Description] FROM dbo.MasterTable WHERE IdTable = 53 AND IdColumn = @IdDireccion) AS Direccion,
	0 AS IdReWeighing,
	'-' AS CardId,
	'-' AS Pila,
	0 AS TareWeight,
	0 AS IdVehicle,
	'-' AS TruckPlate,
	'-' AS Product,
	0 AS GrossWeight,
	'-' AS TrailerPlate,
	'-' AS Quality,
	0 AS NetWeight,
	0 AS InstructedWeight,
	0 AS ReWeight,
	0 AS ToReWeigh,
	0 AS Lotization,
	0 AS Advance,
	0 AS LotToClose,
	0 AS LotSize,
	0 AS DesTare,
	0 AS TareWeightMin,
	0 AS GrossWeightMin,
	0 AS [BatchSize],
	0 AS BatchSizeTolerance,
	0 AS BatchSizeAcumulate,
	CAST(1 AS BIT) AS TareFlag
END

GO

--EXEC [dbo].[ReWeghingWeight_Cancel] 1, 1, ''
ALTER PROCEDURE [dbo].[ReWeghingWeight_Cancel]
@IdCompany INT,
@IdCompanyBranch INT,
@Error VARCHAR(MAX) OUTPUT
AS
BEGIN TRY  
	UPDATE dbo.ReWeightVehicleCardId
	SET IdStatusWeigh = 1
	WHERE IdCompany = @IdCompany
	AND IdCompanyBranch = @IdCompanyBranch
	AND DeletedFlag = 0
    
	UPDATE dbo.MasterTable
	SET Valor =
		CASE IdColumn
			WHEN 1 THEN 10
			WHEN 2 THEN 1
			--WHEN 3 THEN 1
			ELSE Valor
		END
	WHERE IdTable = 54
	AND IdColumn IN (1, 2);
	--COMMIT TRAN  
END TRY  
BEGIN CATCH  
    --ROLLBACK TRAN  
    SET @Error = CONCAT('Línea N°', ERROR_LINE(), ': ', ERROR_MESSAGE())  
END CATCH

GO

--EXEC [dbo].[ReWeighingWeight_Delete] 1,207,28,3, 1, false
ALTER PROCEDURE  [dbo].[ReWeighingWeight_Delete]
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
		UPDATE	ReWeighingWeight SET
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
		SET TareFlag = 0
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
	END

	SELECT 1 AS Ok, '' AS [Message]
END TRY
BEGIN CATCH
    SELECT 0 AS Ok, CONCAT('Línea N°', ERROR_LINE(), ': ', ERROR_MESSAGE()) AS [Message]
END CATCH

GO

ALTER PROCEDURE [dbo].[ReWeighingWeight_InsertUpdate]  
@IdCompany INT,  
@IdCompanyBranch INT,
@IdReWeighingWeight_OG INT,
@IdWeightType INT,
@IdReWeighingWeight INT,  
@IdReWeighing INT,  
@IdVehicle INT,  
@TruckNumber VARCHAR(20),  -- SI NO MANDA ''      
@TrailerNumber VARCHAR(20),  -- SI NO MANDA  ''    
@Weight INT,  
@Obs VARCHAR(100),  
@MemorizedTareFlag BIT,  
@IdCompanyAud INT,  
@IdUserAud INT,  
@ConfirmLotType INT,-- 0:ninguno 1:newlote 2:current lot,  
@IdBascule INT,
@Error VARCHAR(MAX) OUTPUT
AS  
BEGIN TRAN  
BEGIN TRY  
 DECLARE   
 @GrossWeight INT,   
 @TareWeight INT,   
 @NetWeight INT  
 DECLARE   
 @LotFrom INT,  
 @LotTo INT,  
 @LimitLot INT,  
 @LimitWeight INT,  
 @CurrentLot INT,  
 @IsLastLot BIT = 0,  
 @TotalNet INT, -- NETO TOTAL DE TODOS LOS LOTES  
 @TotalNetLot INT, -- NETO TOTAL DE LOTE ACTUAL  
 @BatchSize INT,
 @BatchSizeTolerance INT
  
 DECLARE @Sequence INT,      
   @_ERROR VARCHAR(MAX)  
  
DECLARE @IdValor VARCHAR(1), @ErrorMessage VARCHAR(50)

IF @IdVehicle = 0 AND TRIM(@TruckNumber) = '' AND TRIM(@TrailerNumber) = ''      
BEGIN       
	;THROW 50002, '#VALID! The Truck AND Trailer Number are empty', 1      
END  
IF @Weight <= 0     
BEGIN       
	;THROW 50002, '#VALID! The weight value cannot be less than or equal to zero', 1      
END    
 SELECT 
	@LotFrom = LotFrom, 
	@LotTo = LotTo, 
	@LimitLot = MaxWeighing + ISNULL(MaxWeightTolerance, 0), 
	@LimitWeight = [Weight],
	@BatchSize = ISNULL([BatchSize], 0),
	@BatchSizeTolerance = ISNULL(BatchSizeTolerance, 0)
 FROM ReWeighing WHERE IdCompany = @IdCompany AND IdReWeighing = @IdReWeighing AND DeletedFlag = 0 
 SELECT @CurrentLot =ISNULL(MAX(Lot),@LotFrom) FROM ReWeighingWeight WHERE IdCompany = @IdCompany AND IdReWeighing = @IdReWeighing AND DeletedFlag = 0  
 SELECT @TotalNet=ISNULL(SUM(NetWeight),0) FROM ReWeighingWeight WHERE IdCompany = @IdCompany AND IdReWeighing = @IdReWeighing AND DeletedFlag = 0  
 SELECT @TotalNetLot=ISNULL(SUM(NetWeight),0) FROM ReWeighingWeight WHERE IdCompany = @IdCompany AND IdReWeighing = @IdReWeighing AND Lot = @CurrentLot AND DeletedFlag = 0  
   
 IF @LotTo = @CurrentLot SET @IsLastLot = 1  
   
-- VEHICLE      
IF @IdVehicle = 0       
BEGIN       
	IF EXISTS (SELECT 1 FROM Vehicle WHERE IdCompany = @IdCompany  
									AND TruckNumber = @TruckNumber AND TrailerNumber = @TrailerNumber AND DeletedFlag = 0)      
	BEGIN      
	  SELECT @IdVehicle = IdVehicle       
	  FROM Vehicle WHERE IdCompany = @IdCompany       
	  AND TruckNumber = @TruckNumber AND TrailerNumber = @TrailerNumber AND DeletedFlag = 0      
	END      
	ELSE      
	BEGIN      
	  SELECT @IdVehicle = ISNULL(MAX(IdVehicle), 0) + 1 FROM Vehicle      
		INSERT INTO Vehicle(IdCompany, IdVehicle, RFID, IdVehicleConfiguration, TruckNumber, TruckLong, TruckWidth, TruckHigh,  
		TruckInscription, TruckTare, TruckBrand, TruckModel, TruckMotor, IdTrailerType,       
		TrailerNumber, TrailerLong, TrailerWidth, TrailerHigh, TrailerInscription, TrailerTare,      
		BonusFlag, BonusExpirationDate, BonusMaxGrossWeight, IdCarrier, IdDriver,      
		IdStatus, DeletedFlag, CreatedIdCompany, CreatedIdUser, CreatedDate, IdCompanyBranch)      
		VALUES (@IdCompany, @IdVehicle, '', NULL, @TruckNumber, 0, 0, 0,       
		'', 0, '', '', '', 1, @TrailerNumber, 0, 0, 0, '', 0, 0, dbo.FechaUTC(@IdCompany, @IdCompanyBranch), 0, NULL,      
		0, 1, 0, @IdCompanyAud, @IdUserAud, dbo.FechaUTC(@IdCompany, @IdCompanyBranch), @IdCompanyBranch)      
	END      
END      
	SET @Error = ''  

-- (2023-01-24) Edición de RE-PESO
IF @IdReWeighingWeight_OG != 0
BEGIN
	IF @IdWeightType = 1 -- Gross
	BEGIN
		SET @GrossWeight = @Weight
		SET @TareWeight = ISNULL((SELECT TareWeight FROM dbo.ReWeighingWeight
						  WHERE IdCompany = @IdCompany
						  AND IdCompanyBranch = @IdCompanyBranch
						  AND IdReWeighingWeight = @IdReWeighingWeight_OG), 0)
	END
	ELSE
	BEGIN
		SET @GrossWeight = ISNULL((SELECT GrossWeight FROM dbo.ReWeighingWeight
						  WHERE IdCompany = @IdCompany
						  AND IdCompanyBranch = @IdCompanyBranch
						  AND IdReWeighingWeight = @IdReWeighingWeight_OG), 0)
		SET @TareWeight = @Weight
	END

	SET @NetWeight = IIF(@GrossWeight = 0, 0, @GrossWeight - @TareWeight)
  
	UPDATE dbo.ReWeighingWeight SET      
	IdVehicle = @IdVehicle,  
	Lot = @CurrentLot,
	GrossWeight = @GrossWeight,
	TareWeight = @TareWeight,
	NetWeight = @NetWeight,   
	Obs = @Obs,    
	UpdatedIdCompany = @IdCompanyAud,   
	UpdatedIdUser = @IdUserAud,  
	UpdatedDate = dbo.FechaUTC(@IdCompany, @IdCompanyBranch),
	IdStatusEdit = IIF(@IdWeightType = 1, 2, 1)
	WHERE  IdCompany = @IdCompany
	AND IdReWeighing = @IdReWeighing
	AND IdReWeighingWeight = @IdReWeighingWeight_OG
	AND IdCompanyBranch = @IdCompanyBranch  
	AND DeletedFlag = 0  
  
	UPDATE dbo.ReWeighing SET  
	ReWeight = @TotalNet + @NetWeight,  
	DateEnd = dbo.FechaUTC(@IdCompany, @IdCompanyBranch),
	IdStatusEdit = IIF(@IdWeightType = 1, 2, 1)
	WHERE IdCompany = @IdCompany   
	AND IdReWeighing = @IdReWeighing  
	AND DeletedFlag = 0  
END
ELSE
BEGIN
IF @IdReWeighingWeight = 0
    BEGIN  
  ------ nuevo  
	IF EXISTS(SELECT 1 FROM ReWeighingWeight WHERE IdCompany = @IdCompany  
             AND IdCompanyBranch = @IdCompanyBranch  
             AND IdReWeighing = @IdReWeighing   
             AND GrossWeight = 0   
             AND IdVehicle = @IdVehicle   
             AND DeletedFlag = 0)  
	BEGIN       
	;THROW 50002, '#VALID! The vehicle already has a tare weight', 1      
	END  

	SELECT @IdValor = Valor FROM dbo.MasterTable WHERE IdTable = 54 AND IdColumn = 2
	IF (@IdValor IN (4, 5))
	BEGIN
	SET @ErrorMessage = IIF(@IdValor = 4, '#VALID! Peso Bruto fuera de rango', '#VALID! Peso Tara fuera de rango')
	;THROW 50002, @ErrorMessage, 1   
	END
  -----  
    SET NOCOUNT ON  
	SET @Sequence = ISNULL((SELECT MAX([Sequence]) FROM ReWeighingWeight       
	WHERE IdReWeighing = @IdReWeighing AND IdCompany = @IdCompany AND IdCompanyBranch = @IdCompanyBranch AND DeletedFlag=0),0) + 1      
        
	SELECT @IdReWeighingWeight = ISNULL(MAX(IdReWeighingWeight), 0) + 1 FROM ReWeighingWeight WHERE IdCompany = @IdCompany 
	SET @Error = CONCAT('#PARAMS! ', @IdReWeighingWeight)
	SET NOCOUNT OFF        
  IF @MemorizedTareFlag = 0  
  BEGIN   
   INSERT INTO ReWeighingWeight(  
      IdCompany, IdReWeighingWeight, IdReWeighing, IdVehicle, Lot, GrossWeight, TareWeight, NetWeight, Obs,  
      TareDate, MemorizedTareFlag, IdStatusWeight, IdStatus, DeletedFlag, CreatedIdCompany,   
      CreatedIdUser, CreatedDate, IdCompanyBranch, InputIdBascule, [Sequence]  
   ) VALUES (  
       @IdCompany, @IdReWeighingWeight, @IdReWeighing, @IdVehicle, @CurrentLot, 0, @Weight, 0, @Obs,   
       dbo.FechaUTC(@IdCompany, @IdCompanyBranch), @MemorizedTareFlag, 1, 1, 0, @IdCompanyAud, @IdUserAud,   
       dbo.FechaUTC(@IdCompany, @IdCompanyBranch), @IdCompanyBranch, @IdBascule, @Sequence)  
  
	UPDATE ReWeighing SET  
	DateStart = dbo.FechaUTC(@IdCompany, @IdCompanyBranch),  
	DateEnd = dbo.FechaUTC(@IdCompany, @IdCompanyBranch)  
	WHERE IdCompany = @IdCompany AND IdReWeighing = @IdReWeighing AND IdStatus = 1 
   
	UPDATE ReWeighing SET  
	IdStatus = 2  
	WHERE IdCompany = @IdCompany AND IdReWeighing = @IdReWeighing  
     
	UPDATE dbo.ReWeightVehicleCardId
	SET IdStatusWeigh = 1
	WHERE IdCompany = @IdCompany
	AND IdCompanyBranch = @IdCompanyBranch
	AND IdReWeighing = @IdReWeighing
	AND DeletedFlag = 0

	UPDATE dbo.MasterTable
	SET Valor = 
		CASE IdColumn
			WHEN 1 THEN 2
			WHEN 2 THEN 1
			WHEN 3 THEN 1
			ELSE Valor
		END
	WHERE IdTable = 54
	AND IdColumn IN (1, 2, 3)

  END  
  ELSE IF @MemorizedTareFlag = 1
  BEGIN  
   SET @TareWeight =ISNULL((select top 1 rewe.TareWeight from ReWeighingWeight rewe   
    where rewe.IdCompany = @IdCompany and rewe.IdVehicle = @IdVehicle  AND DeletedFlag = 0
    order by IdReWeighingWeight desc),0) 

	IF @TareWeight <= 0
	BEGIN
		BEGIN       
		;THROW 50002, '#VALID! The vehicle does not have a tare weight', 1      
  END 
	END
   SET @NetWeight = @Weight - @TareWeight  
  
   IF @NetWeight <= 0    
   BEGIN       
   ;THROW 50002, '#VALID! Gross Weight cannot be less than or equal to Tare Weight', 1      
   END  
   --IF @TotalNet + @NetWeight > @LimitWeight  
   --BEGIN  
   -- ;THROW 50002, '#VALID! The Limit has been exceeded', 1  
   --END  
  
   IF (@TotalNetLot + @NetWeight) > @LimitLot  
   BEGIN  
    IF @TotalNetLot * 0 > @LimitLot  
    BEGIN  
     SET @CurrentLot = @CurrentLot + 1  
    END  
    ELSE  
    BEGIN  
     --IF @ConfirmLotType = 1  
     --BEGIN  
      SET @CurrentLot = @CurrentLot + 1  
     --END  
     --ELSE IF @ConfirmLotType = 2  
     --BEGIN   
     -- SET @CurrentLot=@CurrentLot  
     --END  
     --ELSE  
     --BEGIN  
     -- SET @_ERROR = '#CONFIRM! There is a difference of '++CAST((@TotalNetLot + @NetWeight) - @LimitLot AS VARCHAR)+' Kg. It will generate new Lot '+CAST(@CurrentLot + 1 AS VARCHAR)  
     -- ;THROW 50003, @_ERROR, 1  
     --END  
    END  
   END  
  
   INSERT INTO ReWeighingWeight(  
      IdCompany, IdReWeighingWeight, IdReWeighing, IdVehicle, Lot, GrossWeight, TareWeight, NetWeight, Obs, GrossDate,  
      TareDate, MemorizedTareFlag, IdStatusWeight, IdStatus, DeletedFlag, CreatedIdCompany,   
      CreatedIdUser, CreatedDate, IdCompanyBranch, InputIdBascule, OutputIdBascule, [Sequence]  
   ) VALUES (  
       @IdCompany, @IdReWeighingWeight, @IdReWeighing, @IdVehicle, @CurrentLot, @Weight, @TareWeight, @NetWeight, @Obs,  
       dbo.FechaUTC(@IdCompany, @IdCompanyBranch), dbo.FechaUTC(@IdCompany, @IdCompanyBranch), @MemorizedTareFlag,   
       2, 1, 0, @IdCompanyAud, @IdUserAud, dbo.FechaUTC(@IdCompany, @IdCompanyBranch), @IdCompanyBranch, @IdBascule,  
       @IdBascule, @Sequence) 

   UPDATE ReWeighing SET  
    DateStart = dbo.FechaUTC(@IdCompany, @IdCompanyBranch),  
    DateEnd = dbo.FechaUTC(@IdCompany, @IdCompanyBranch)  
   WHERE IdCompany = @IdCompany AND IdReWeighing = @IdReWeighing AND IdStatus = 1    
   UPDATE ReWeighing SET  
    ReWeight = @TotalNet + @NetWeight,  
    IdStatus = 2,  
    DateEnd = dbo.FechaUTC(@IdCompany, @IdCompanyBranch)  
   WHERE IdCompany = @IdCompany AND IdReWeighing = @IdReWeighing 

	UPDATE dbo.ReWeightVehicleCardId
	SET IdStatusWeigh = 1
	WHERE IdCompany = @IdCompany
	AND IdCompanyBranch = @IdCompanyBranch
	AND IdReWeighing = @IdReWeighing
	AND DeletedFlag = 0

	UPDATE dbo.MasterTable
	SET Valor = 
		CASE IdColumn
			WHEN 1 THEN 2
			WHEN 2 THEN 1
			WHEN 3 THEN 1
			ELSE Valor
		END
	WHERE IdTable = 54
	AND IdColumn IN (1, 2, 3)
  END          
    END  
ELSE  ------------------
  BEGIN  
  ------ nuevo  
  IF NOT EXISTS(SELECT 1 FROM ReWeighingWeight WHERE IdCompany = @IdCompany   
             AND IdCompanyBranch = @IdCompanyBranch  
             AND IdReWeighing = @IdReWeighing  
             AND TareWeight > 0  
             AND GrossWeight = 0   
             AND IdVehicle = @IdVehicle   
             AND DeletedFlag = 0)  
  BEGIN       
  ;THROW 50002, '#VALID! The vehicle does not have a tare weight', 1      
  END 
  
  SELECT @IdValor = Valor FROM dbo.MasterTable WHERE IdTable = 54 AND IdColumn = 2
	IF (@IdValor IN (4, 5))
	BEGIN
	SET @ErrorMessage = IIF(@IdValor = 4, '#VALID! Peso Bruto fuera de rango', '#VALID! Peso Tara fuera de rango')
	;THROW 50002, @ErrorMessage, 1   
	END
  -----  
  --SELECT @TareWeight = TareWeight FROM ReWeighingWeight WHERE IdCompany = @IdCompany AND IdReWeighingWeight = @IdReWeighingWeight  
  SELECT @TareWeight = TareWeight FROM ReWeighingWeight 
									WHERE IdCompany = @IdCompany 
									AND IdCompanyBranch = @IdCompanyBranch
									AND IdReWeighing = @IdReWeighing
									AND IdVehicle = @IdVehicle AND GrossWeight = 0  

  SET @NetWeight = @Weight - @TareWeight 
    
  IF @NetWeight <= 0    
  BEGIN       
  ;THROW 50002, '#VALID! Gross Weight cannot be less than or equal to Tare Weight', 1      
  END  
  --IF @TotalNet + @NetWeight > @LimitWeight  
  --BEGIN  
  -- ;THROW 50002, '#VALID! The Limit has been exceeded', 1  
  --END  
  
  IF (@TotalNetLot + @NetWeight) > @LimitLot
  BEGIN  
   IF @TotalNetLot * 0 > @LimitLot  
   BEGIN  
    SET @CurrentLot = @CurrentLot + 1  
   END  
   ELSE  
   BEGIN  
    --IF @ConfirmLotType = 1  
    --BEGIN  
     SET @CurrentLot = @CurrentLot + 1  
    --END  
    --ELSE IF @ConfirmLotType = 2  
    --BEGIN   
    -- SET @CurrentLot=@CurrentLot  
    --END  
    --ELSE  
    --BEGIN  
    --  SET @_ERROR = '#CONFIRM! There is a difference of '++CAST((@TotalNetLot + @NetWeight) - @LimitLot AS VARCHAR)+' Kg. It will generate new Lot '+CAST(@CurrentLot + 1 AS VARCHAR)  
    -- ;THROW 50003, @_ERROR, 1  
    --END  
   END  
  END  
  
  SELECT @IdReWeighingWeight = IdReWeighingWeight 
	FROM dbo.ReWeighingWeight WHERE IdCompany = @IdCompany
	   AND IdReWeighing = @IdReWeighing
	   AND IdCompanyBranch = @IdCompanyBranch  
	   AND IdVehicle = @IdVehicle  
	   AND GrossWeight = 0  
	   AND DeletedFlag = 0

  UPDATE ReWeighingWeight SET      
  IdReWeighing = @IdReWeighing,   
  IdVehicle = @IdVehicle,  
  Lot = @CurrentLot,  
  GrossWeight = @Weight,   
  NetWeight = @NetWeight,   
  Obs = @Obs,   
  GrossDate = dbo.FechaUTC(@IdCompany, @IdCompanyBranch),    
  MemorizedTareFlag = @MemorizedTareFlag,   
  IdStatusWeight = 2,  
  OutputIdBascule = @IdBascule,
  IdStatus = 1,  
  UpdatedIdCompany = @IdCompanyAud,   
  UpdatedIdUser = @IdUserAud,  
  UpdatedDate = dbo.FechaUTC(@IdCompany, @IdCompanyBranch)  
  WHERE  IdCompany = @IdCompany
   AND IdReWeighing = @IdReWeighing
   --AND IdReWeighingWeight = @IdReWeighingWeight
   AND IdCompanyBranch = @IdCompanyBranch  
   AND IdVehicle = @IdVehicle  
   AND GrossWeight = 0  
   AND DeletedFlag = 0  
  
	UPDATE ReWeighing SET  
	ReWeight = @TotalNet + @NetWeight,  
	DateEnd = dbo.FechaUTC(@IdCompany, @IdCompanyBranch)  
	WHERE IdCompany = @IdCompany   
	AND IdReWeighing = @IdReWeighing  
	AND DeletedFlag = 0 
  
	UPDATE dbo.ReWeightVehicleCardId
	SET IdStatusWeigh = 1
	WHERE IdCompany = @IdCompany
	AND IdCompanyBranch = @IdCompanyBranch
	AND IdReWeighing = @IdReWeighing
	AND DeletedFlag = 0

	--DECLARE @ReWeight INT = @TotalNet + @NetWeight
	--DECLARE @NewBatchSize INT = @BatchSize
	--IF ((SELECT LimitBatchSize FROM dbo.ReWeighing_Batch WHERE IdReWeighing = @IdReWeighing) >= @BatchSize)
	--BEGIN
	--	SELECT @NewBatchSize = LimitBatchSize FROM dbo.ReWeighing_Batch WHERE IdReWeighing = @IdReWeighing
	--END
	--DECLARE @MinBatch INT = @NewBatchSize - @BatchSizeTolerance
	--DECLARE @MaxBatch INT = @NewBatchSize + @BatchSizeTolerance


	--UPDATE dbo.MasterTable
	--SET Valor = 1
	--WHERE IdTable = 54
	--AND IdColumn IN (1, 2)

	--IF (@ReWeight BETWEEN @MinBatch AND @MaxBatch)
	--BEGIN
	--	UPDATE dbo.MasterTable
	--	SET Valor = 4
	--	WHERE IdTable = 54
	--	AND IdColumn = 3
	--END
	--ELSE IF (@ReWeight > @MaxBatch)
	--BEGIN
	--	UPDATE dbo.MasterTable
	--	SET Valor = 5
	--	WHERE IdTable = 54
	--	AND IdColumn = 3

	--	UPDATE dbo.ReWeighing_Batch
	--	SET LimitBatchSize = @NewBatchSize + @BatchSize
	--	WHERE IdReWeighing = @IdReWeighing
	--END
	--ELSE
	--BEGIN
	--	UPDATE dbo.MasterTable
	--	SET Valor = 1
	--	WHERE IdTable = 54
	--	AND IdColumn = 3
	--END

	SET @Error = CONCAT('#PARAMS! ', @IdReWeighingWeight)
	END
END
  
  DECLARE @ReWeight INT = @TotalNet + @NetWeight
	DECLARE @NewBatchSize INT = @BatchSize
	IF ((SELECT LimitBatchSize FROM dbo.ReWeighing_Batch WHERE IdReWeighing = @IdReWeighing) >= @BatchSize)
	BEGIN
		SELECT @NewBatchSize = LimitBatchSize FROM dbo.ReWeighing_Batch WHERE IdReWeighing = @IdReWeighing
	END
	DECLARE @MinBatch INT = @NewBatchSize - @BatchSizeTolerance
	DECLARE @MaxBatch INT = @NewBatchSize + @BatchSizeTolerance


	UPDATE dbo.MasterTable
	SET Valor = 1
	WHERE IdTable = 54
	AND IdColumn IN (1, 2)

	IF (@ReWeight BETWEEN @MinBatch AND @MaxBatch)
	BEGIN
		UPDATE dbo.MasterTable
		SET Valor = 4
		WHERE IdTable = 54
		AND IdColumn = 3
	END
	ELSE IF (@ReWeight > @MaxBatch)
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
		WHERE IdCompany = @IdCompany
		AND IdCompanyBranch = @IdCompanyBranch
		AND IdReWeighing = @IdReWeighing
		AND DeletedFlag = 0
	END
	ELSE
	BEGIN
		UPDATE dbo.MasterTable
		SET Valor = 1
		WHERE IdTable = 54
		AND IdColumn = 3

		UPDATE dbo.ReWeightVehicleCardId
		SET TareFlag = 0
		WHERE IdCompany = @IdCompany
		AND IdCompanyBranch = @IdCompanyBranch
		AND IdReWeighing = @IdReWeighing
		AND IdVehicle = @IdVehicle
		AND DeletedFlag = 0
	END

    COMMIT TRAN  
END TRY  
BEGIN CATCH  
    ROLLBACK TRAN  
    SET @Error = CONCAT('Línea N°', ERROR_LINE(), ': ', ERROR_MESSAGE())  
END CATCH  
