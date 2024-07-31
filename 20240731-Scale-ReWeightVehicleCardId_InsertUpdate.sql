ALTER PROCEDURE [dbo].[ReWeightVehicleCardId_InsertUpdate]
@IdCompany INT,
@IdCompanyBranch INT,
@IdReWeightVehicleCardId INT,
@IdReWeighing INT,
@IdVehicle INT,
@IdCard INT,
@FlagReasignar BIT,
@IdStatus INT,
@IdUserAud INT,
@IdCompanyAud INT,
@Error varchar(MAX) OUTPUT
AS
BEGIN TRAN
BEGIN TRY
	IF @IdReWeightVehicleCardId = 0
	BEGIN
		SELECT 
		@IdReWeightVehicleCardId = ISNULL(MAX(IdReWeightVehicleCardId), 0) + 1 
		FROM dbo.ReWeightVehicleCardId WHERE IdCompany = @IdCompany AND IdCompanyBranch = @IdCompanyBranch

		INSERT INTO dbo.ReWeightVehicleCardId(IdCompany, IdCompanyBranch, IdReWeightVehicleCardId, IdReWeighing, 
						IdVehicle, IdCardId, IdStatus, IdStatusWeigh, DeletedFlag, CreatedIdCompany,
							CreatedIdUser, CreatedDate)
		SELECT
		@IdCompany,
		@IdCompanyBranch,
		@IdReWeightVehicleCardId,
		@IdReWeighing,
		@IdVehicle,
		@IdCard,
		@IdStatus,
		1,
		0 AS DeleteFlag,
		@IdCompanyAud,
		@IdUserAud,
		dbo.FechaUTC(@IdCompany, @IdCompanyBranch)
	END
	ELSE IF @IdReWeightVehicleCardId > 0
	BEGIN
		UPDATE ReWeightVehicleCardId SET
		IdReWeighing = @IdReWeighing,
		IdVehicle = @IdVehicle,
		IdCardId = @IdCard,
		UpdatedIdCompany= @IdCompanyAud,
		UpdatedIdUser = @IdUserAud
		WHERE IdCompany = @IdCompany
		AND IdCompanyBranch = @IdCompanyBranch
		AND IdReWeightVehicleCardId = @IdReWeightVehicleCardId
	END

	IF(@FlagReasignar = 1)
	BEGIN
	
	UPDATE ReWeightVehicleCardId SET
	IdCardId = @IdCard,
	UpdatedIdCompany= @IdCompanyAud,
	UpdatedIdUser = @IdUserAud
	WHERE IdCompany = @IdCompany
	AND IdCompanyBranch = @IdCompanyBranch
	AND IdReWeightVehicleCardId = @IdReWeightVehicleCardId
	
	UPDATE ReWeightVehicleCardId SET
	DeletedFlag = 1,
	UpdatedIdCompany= @IdCompanyAud,
	UpdatedIdUser = @IdUserAud
	WHERE IdCompany = @IdCompany
	AND IdCompanyBranch = @IdCompanyBranch
	AND IdReWeightVehicleCardId <> @IdReWeightVehicleCardId
	AND IdCardId = @IdCard

	END

	IF (SELECT COUNT(1) 
		FROM ReWeightVehicleCardId car
		INNER JOIN ReWeighing re ON re.IdCompany = car.IdCompany 
									AND re.IdCompanyBranch = car.IdCompanyBranch 
									AND re.IdReWeighing = car.IdReWeighing 
									AND re.IdStatus < 3
		WHERE car.IdCompany = @IdCompany
		AND car.IdCompanyBranch = @IdCompanyBranch
		--AND IdReWeighing = @IdReWeighing
		--AND IdVehicle = @IdVehicle
		AND car.IdCardId = @IdCard
		AND car.DeletedFlag = 0) > 1
	BEGIN
		ROLLBACK TRAN
		SET @Error = '#CONFIRM!' + 'Este CardID ya esta asignado a otro vehiculo. Deseas Re-asignar el Card-ID?'
	END
	ELSE IF (SELECT COUNT(1) FROM ReWeightVehicleCardId car
		INNER JOIN ReWeighing re ON re.IdCompany = car.IdCompany 
									AND re.IdCompanyBranch = car.IdCompanyBranch 
									AND re.IdReWeighing = car.IdReWeighing 
									AND re.IdStatus < 3
		WHERE car.IdCompany = @IdCompany
		AND car.IdCompanyBranch = @IdCompanyBranch
		AND re.IdReWeighing = @IdReWeighing
		AND car.IdVehicle = @IdVehicle
		AND car.DeletedFlag = 0) > 1
	BEGIN
		ROLLBACK TRAN
		SET @Error = '#VALID!' + 'Este vehículo ya esta registrado en este lote'
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
