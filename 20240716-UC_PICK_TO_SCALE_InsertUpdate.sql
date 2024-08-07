ALTER PROCEDURE [dbo].[UC_PICK_TO_SCALE_InsertUpdate]
@SEGNAM VARCHAR(25),
@TRNTYP VARCHAR(25), 
@ORDNUM VARCHAR(25),
@WHSE_ID VARCHAR(25),
@CLIENT_ID VARCHAR(25),
@SHIP_ID VARCHAR(25), 
@WAVENUM VARCHAR(25), 
@PRTNUM VARCHAR(25),
@INV_ATTR_STR1 VARCHAR(25),
@QTY VARCHAR(25),
@INV_ATTR_STR5 VARCHAR(25),
@STOLOC VARCHAR(25), 
@UC_CONVEYOR VARCHAR(25),
@UC_CONTAINER_FLG VARCHAR(25), 
@VC_SAMPLE_CLIENT VARCHAR(25),
@VC_SAMPLE_PROD VARCHAR(25),
@UC_SAMP_PL VARCHAR(25),
@EXTRL_SRVYR VARCHAR(25),
@ADNL_TST_REQD VARCHAR(25),
@IdCompanyAud INT,
@IdUserAud INT,
@IdTransportation INT,
@OriginIdSeaPort INT,
@Humidity DECIMAL(5,2),
@DAM VARCHAR(20),
@GuideIssuerId INT,
@IssuingClientId INT,
@OrigenIdAnexo INT,
@DestinoIdAnexo INT,
@Error VARCHAR(MAX) OUTPUT
AS
DECLARE @IdCompanyBranch INT
DECLARE @IdClient INT
BEGIN TRAN
BEGIN TRY
SET @IdCompanyBranch = (SELECT IdCompanyBranch FROM CompanyBranch WHERE CodeCompanyBranch = @WHSE_ID)
	IF NOT EXISTS (SELECT 1 FROM UC_PICK_TO_SCALE WHERE ORDNUM = @ORDNUM)
	BEGIN
		INSERT INTO UC_PICK_TO_SCALE
		(SEGNAM, TRNTYP, ORDNUM, WHSE_ID, CLIENT_ID, SHIP_ID, WAVENUM, PRTNUM, INV_ATTR_STR1, QTY, INV_ATTR_STR5,
		STOLOC, UC_CONVEYOR, UC_CONTAINER_FLG, VC_SAMPLE_CLIENT, VC_SAMPLE_PROD, UC_SAMP_PL, EXTRL_SRVYR, ADNL_TST_REQD, 
		DeletedFlag, CreatedIdCompany, CreatedIdUser, CreatedDate, DAM, GuideIssuerId, IssuingClientId, IdTransportation, Humidity, OriginIdSeaport,
		OrigenIdAnexo, DestinoIdAnexo)
		VALUES 
		(@SEGNAM, @TRNTYP, @ORDNUM, @WHSE_ID, @CLIENT_ID, @SHIP_ID, @WAVENUM, @PRTNUM, @INV_ATTR_STR1, @QTY, @INV_ATTR_STR5,
		@STOLOC, @UC_CONVEYOR, @UC_CONTAINER_FLG,  @VC_SAMPLE_CLIENT, @VC_SAMPLE_PROD, @UC_SAMP_PL, @EXTRL_SRVYR, @ADNL_TST_REQD,
		0, @IdCompanyAud, @IdUserAud, GETUTCDATE(), @DAM, @GuideIssuerId, @IssuingClientId, @IdTransportation, @Humidity, @OriginIdSeaPort, @OrigenIdAnexo, @DestinoIdAnexo)
	END
	ELSE
	BEGIN
		UPDATE UC_PICK_TO_SCALE SET
		SEGNAM = @SEGNAM,
		TRNTYP = @TRNTYP,
		WHSE_ID = @WHSE_ID,
		CLIENT_ID = @CLIENT_ID,
		SHIP_ID = @SHIP_ID, 
		WAVENUM = @WAVENUM, 
		PRTNUM = @PRTNUM,
		INV_ATTR_STR1 = @INV_ATTR_STR1,
		QTY = @QTY,
		@INV_ATTR_STR5 = @INV_ATTR_STR5,
		STOLOC = @STOLOC, 
		UC_CONVEYOR = @UC_CONVEYOR,
		UC_CONTAINER_FLG = @UC_CONTAINER_FLG, 
		VC_SAMPLE_CLIENT = @VC_SAMPLE_CLIENT,
		VC_SAMPLE_PROD = @VC_SAMPLE_PROD,
		UC_SAMP_PL = @UC_SAMP_PL,
		EXTRL_SRVYR = @EXTRL_SRVYR,
		ADNL_TST_REQD = @ADNL_TST_REQD,
		DeletedFlag = 0,
		CreatedIdCompany = @IdCompanyAud,
		CreatedIdUser = @IdUserAud,
		CreatedDate = GETUTCDATE(),
		OriginIdSeaPort = @OriginIdSeaPort,
		Humidity = @Humidity,
		DAM = @DAM,
		GuideIssuerId = @GuideIssuerId,
		IssuingClientId = @IssuingClientId,
		IdTransportation = @IdTransportation,
		OrigenIdAnexo = @OrigenIdAnexo,
		DestinoIdAnexo = @DestinoIdAnexo
		WHERE ORDNUM = @ORDNUM
	END
	
	IF (SELECT COUNT(1) FROM UC_PICK_TO_SCALE WHERE ORDNUM = @ORDNUM ) > 1
	BEGIN
		ROLLBACK TRAN
        SET @Error = '#VALID!' + 'The ORDNUM already exists'
	END
	ELSE IF (@IdCompanyBranch = 1)
	BEGIN
		IF (SELECT COUNT(1) FROM dbo.Weighing WHERE IDOUTBOUND = @ORDNUM AND DeletedFlag = 0 AND IdCompanyBranch = @IdCompanyBranch) > 0
		BEGIN
			SET @IdClient = (SELECT IdClient FROM dbo.Client WHERE IdCompanyBranch = @IdCompanyBranch AND ClientNumber = @CLIENT_ID)

			IF @IdClient IS NULL
			BEGIN
				ROLLBACK TRAN
				SET @Error = '#VALID! Código de cliente no existe en el mantenimiento de cliente'
			END
			ELSE
			BEGIN
				UPDATE dbo.Weighing SET

				ItemNumber = @PRTNUM,
				Quality = @INV_ATTR_STR1,
				StorageLocation = @STOLOC,
				IdClient = @IdClient,
				ClientCode = @CLIENT_ID,

				UpdatedDate = dbo.FechaUTC(@IdCompanyAud, @IdCompanyBranch),
				UpdatedIdCompany = @IdCompanyAud,
				UpdatedIdUser = @IdUserAud
				WHERE IDOUTBOUND = @ORDNUM
				AND DeletedFlag = 0
				AND IdCompanyBranch = @IdCompanyBranch
				
				COMMIT TRAN
			END
		END
		ELSE
		BEGIN
			COMMIT TRAN
		END
	END
END TRY
BEGIN CATCH
	ROLLBACK TRAN
	SET @Error = CONCAT('Línea N°', ERROR_LINE(), ': ', ERROR_MESSAGE())
END CATCH