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
@WeightMinTare INT

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
IIF(ISNULL(rww.TareWeight, 0) = 0, @Weight, rww.TareWeight) AS TareWeight,
ve.IdVehicle,
ve.TruckNumber AS TruckPlate,
pr.DescProduct AS Product,
IIF(ISNULL(rww.TareWeight, 0) = 0, 0, @Weight) AS GrossWeight,
ve.TrailerNumber AS TrailerPlate,
qu.[Description] AS Quality,
IIF(rww.TareWeight = 0, 0, @Weight - rww.TareWeight) AS NetWeight,
1500000 AS InstructedWeight,
rw.[Weight] AS ReWeight,
rw.[Weight] - rw.ReWeight AS ToReWeigh,
rw.MaxWeighing AS Lotization,
rw.ReWeight AS Advance,
rw.LotTo AS LotToClose,
rw.MaxWeighing AS LotSize,
1500 AS DesTare,
rwvc.IdStatusWeigh,
(ve.TruckTare + ve.TrailerTare - TruckTareTolerance) AS TareWeightMin,
(ve.TruckTare + ve.TrailerTare + TruckTareTolerance) AS GrossWeightMin,
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
		SELECT 
		--TOP(1)
		--@IdCapturaPeso = IIF((GrossWeight = 0 AND @TareWeight = 0), 
		--					IIF(TareWeight < ISNULL(TareWeightMin, @WeightMinTare), 5, 2), 
		--					IIF(IIF(TareFlag = 0, @Weight, TareWeight) > ISNULL(GrossWeightMin, TareWeight), 3, 4)),
		@IdCapturaPeso = IIF(TareFlag = 1, 
						IIF(TareWeight < ISNULL(TareWeightMin, @WeightMinTare), 5, 2), 
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
		IIF(TareFlag = 1, ISNULL(da.TareWeight, 0), @TareWeight) AS TareWeight,
		da.IdVehicle,
		da.TruckPlate,
		da.Product,
		IIF(TareFlag = 1, 0, @Weight) AS GrossWeight,
		--ISNULL(da.GrossWeight, 0) AS GrossWeight,
		da.TrailerPlate,
		da.Quality,
		--ISNULL(da.GrossWeight, 0) - ISNULL(da.TareWeight, 0) AS NetWeight,
		IIF(TareFlag = 1, 0, @Weight - @TareWeight) AS NetWeight,
		da.InstructedWeight,
		da.ReWeight,
		da.ToReWeigh,
		da.Lotization,
		(da.Advance + IIF(@TareWeight = 0, 0, @Weight - @TareWeight)) AS Advance,
		da.LotToClose,
		da.LotSize,
		da.DesTare,
		ISNULL(da.TareWeightMin, 0) AS TareWeightMin,
		ISNULL(da.GrossWeightMin, 0) AS GrossWeightMin,
		[BatchSize],
		BatchSizeTolerance,
		BatchSizeAcumulate,
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