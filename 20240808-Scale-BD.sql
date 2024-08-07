-- [dbo].[ReWighing_TV_GetByBascule] 1, 1, 0, 1
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
rw.IdStatus AS IdStatusRW
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

		SET @TareWeight = ISNULL((select top 1 rewe.TareWeight from ReWeighingWeight rewe
															INNER JOIN #data tmp ON tmp.IdReWeighing = rewe.IdReWeighing AND tmp.IdVehicle = rewe.IdVehicle
		where rewe.IdCompany = @IdCompany
		AND rewe.DeletedFlag = 0
		order by rewe.IdReWeighingWeight desc),0) 
		--SELECT @TareWeight
		SELECT 
		--TOP(1)
		@IdCapturaPeso = IIF((GrossWeight = 0 AND @TareWeight = 0), 
							IIF(TareWeight < ISNULL(TareWeightMin, @WeightMinTare), 5, 2), 
							IIF(IIF(@TareWeight = 0, ISNULL(GrossWeight, 0), TareWeight) > ISNULL(GrossWeightMin, TareWeight), 3, 4)),
		@IdDireccion = IIF(GrossWeight = 0, 3, 2)
		FROM #data
		--SET @IdEstadoAutorizado = 2
		
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
		IIF(@TareWeight = 0, ISNULL(da.TareWeight, 0), @TareWeight) AS TareWeight,
		da.IdVehicle,
		da.TruckPlate,
		da.Product,
		--IIF(da.TareWeight = 0, 0, @Weight) AS GrossWeight,
		IIF(@TareWeight = 0, ISNULL(da.GrossWeight, 0), da.TareWeight) AS GrossWeight,
		da.TrailerPlate,
		da.Quality,
		IIF(@TareWeight = 0, ISNULL(da.GrossWeight, 0) - ISNULL(da.TareWeight, 0), da.TareWeight - @TareWeight) AS NetWeight,
		da.InstructedWeight,
		da.ReWeight,
		da.ToReWeigh,
		da.Lotization,
		da.Advance,
		da.LotToClose,
		da.LotSize,
		da.DesTare,
		ISNULL(da.TareWeightMin, 0) AS TareWeightMin,
		ISNULL(da.GrossWeightMin, 0) AS GrossWeightMin
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
		0 AS GrossWeightMin
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
	0 AS GrossWeightMin
END

--INSERT [dbo].[MasterTable] ([IdCompany], [IdTable], [IdColumn], [Valor], [Description], [IdFatherColumn], [IdStatus], [DeletedFlag], [CreatedIdCompany], [CreatedIdUser], [CreatedDate], [UpdatedIdCompany], [UpdatedIdUser], [UpdatedDate]) VALUES (1, 51, 0, N'', N'TV Estado Autorización', NULL, 1, 0, 1, 1, CAST(N'2023-12-12T11:00:00.000' AS DateTime), NULL, NULL, NULL)

GO

-- dbo.Bascule_Update_FlagLeer_Peso 1, 1, 3, 1, 2400, 1, 1, ''
ALTER PROCEDURE [dbo].[Bascule_Update_FlagLeer_Peso]
@IdCompany INT,
@IdCompanyBranch INT,
@IdBascule INT,
@FlagLeer BIT,
@Peso INT,
@Tipo INT, -- 1 Consulta desde el portable, 2 Consulta desde la web
@IdUserAud INT,
@Error VARCHAR(MAX) OUTPUT
AS
BEGIN TRAN
BEGIN TRY
	SET @Error = ''
	IF @Tipo = 1
	BEGIN
		UPDATE Bascule SET
		Peso = @Peso
		WHERE IdCompany = @IdCompany
		AND IdCompanyBranch = @IdCompanyBranch
		AND IdBascule = @IdBascule
	END
	ELSE
	BEGIN
		UPDATE Bascule SET
		FlagLeer = @FlagLeer,
		Peso = @Peso,
		IdCurrentUser = @IdUserAud,
		UpdatedIdCompany = @IdCompany,
		UpdatedIdUser = @IdUserAud,
		UpdatedDate = dbo.FechaUTC(@IdCompany, @IdCompanyBranch)
		WHERE IdCompany = @IdCompany
		AND IdCompanyBranch = @IdCompanyBranch
		AND IdBascule = @IdBascule
	END
	IF (SELECT COUNT(*) FROM Bascule WHERE IdCompany = @IdCompany
										AND IdCompanyBranch = @IdCompanyBranch
										AND IdBascule = @IdBascule 
										AND IdStatus = 1 
										AND DeletedFlag = 0) = 0
    BEGIN
        ROLLBACK TRAN
        SET @Error = '#VALID!' + 'The Bascule does not exist'
    END
    ELSE
    BEGIN
        COMMIT TRAN
    END

END TRY
BEGIN CATCH
    ROLLBACK TRAN
    SET @Error = CONCAT('Línea N°', ERROR_LINE(), ': ', ERROR_MESSAGE())
END CATCH
