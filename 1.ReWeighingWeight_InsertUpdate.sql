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
@FlagAutomatico BIT,
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

-- (2023-01-24) Edici�n de RE-PESO
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
	IF (@IdValor IN (4, 5) AND @FlagAutomatico = 1)
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

	IF @FlagAutomatico = 1
	BEGIN
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
  ELSE IF @MemorizedTareFlag = 1
  BEGIN  
   SET @TareWeight =ISNULL((SELECT TOP 1 rewe.TareWeight FROM dbo.ReWeighingWeight rewe   
    WHERE rewe.IdCompany = @IdCompany 
	AND rewe.IdCompanyBranch = @IdCompanyBranch 
	AND rewe.IdReWeighing = @IdReWeighing
	AND rewe.IdVehicle = @IdVehicle 
	AND DeletedFlag = 0
    ORDER BY rewe.IdReWeighingWeight DESC),0) 

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

	IF @FlagAutomatico = 1
	BEGIN
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
	IF (@IdValor IN (4, 5) AND @FlagAutomatico = 1)
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

	IF @FlagAutomatico = 1
	BEGIN
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
	END

    COMMIT TRAN  
END TRY  
BEGIN CATCH  
    ROLLBACK TRAN  
    SET @Error = CONCAT('L�nea N�', ERROR_LINE(), ': ', ERROR_MESSAGE())  
END CATCH
