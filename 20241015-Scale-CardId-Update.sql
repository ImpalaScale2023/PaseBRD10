ALTER TABLE [dbo].[CardId]
ALTER COLUMN CodCard VARCHAR(30)

GO

ALTER TABLE [dbo].[CardId]
ALTER COLUMN DescriptionCard VARCHAR(50)

GO

ALTER PROCEDURE [dbo].[Card_InsertUpdate]
@IdCompany INT,
@IdCompanyBranch INT,
@IdCard INT,
@CodCard VARCHAR(30),
@DescriptionCard VARCHAR(50),
@IdStatus INT,
@IdUserAud INT,
@IdCompanyAud INT,
@Error varchar(MAX) OUTPUT
AS
BEGIN TRAN
BEGIN TRY
	IF @IdCard = 0
	BEGIN
		SELECT @IdCard = MAX(IdCard) FROM dbo.CardId WHERE IdCompany = @IdCompany AND IdCompanyBranch = @IdCompanyBranch
		INSERT INTO CardId(IdCompany, IdCard, IdCompanyBranch, CodCard, DescriptionCard, IdStatus, DeletedFlag, CreatedIdCompany,
							CreatedIdUser, CreatedDate)
		SELECT
		@IdCompany,
		ISNULL(@IdCard, 0) + 1,
		@IdCompanyBranch,
		@CodCard,
		@DescriptionCard,
		@IdStatus,
		0 AS DeleteFlag,
		@IdCompanyAud,
		@IdUserAud,
		dbo.FechaUTC(@IdCompany, @IdCompanyBranch)
	END
	ELSE IF @IdCard > 0
	BEGIN
		UPDATE CardId SET
		CodCard = @CodCard,
		IdStatus = @IdStatus,
		DescriptionCard = @DescriptionCard,
		UpdatedIdCompany = @IdCompanyAud,
		UpdatedIdUser = @IdUserAud
		WHERE IdCompany = @IdCompany
		AND IdCompanyBranch = @IdCompanyBranch
		AND IdCard = @IdCard
	END

	IF (SELECT COUNT(1) FROM CardId WHERE IdCompany = @IdCompany
		AND IdCompanyBranch = @IdCompanyBranch
		AND CodCard = @CodCard
		AND DeletedFlag = 0) > 1
	BEGIN
		ROLLBACK TRAN
		SET @Error = '#VALID!' + 'This register already exists'
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

GO