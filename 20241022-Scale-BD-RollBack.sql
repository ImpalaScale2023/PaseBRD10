ALTER PROCEDURE [dbo].[ReWeightVehicleCardId_List]
@IdCompany INT,
@IdCompanyBranch INT,
@IdReWeighing INT,
@TimeZone INT,
@IdStatus INT,
@Search VARCHAR(50),
@PageIndex INT,
@PageSize INT
AS
DECLARE @TotalElements INT
SELECT @TotalElements = COUNT(1) 
FROM dbo.ReWeightVehicleCardId an
INNER JOIN dbo.Vehicle ve ON an.IdCompany = ve.IdCompany AND ve.IdVehicle = an.IdVehicle
INNER JOIN dbo.CardId ca ON an.IdCompany = ca.IdCompany AND an.IdCompanyBranch = ca.IdCompanyBranch AND ca.IdCard = an.IdCardId AND ca.DeletedFlag = 0
INNER JOIN MasterTable tblm ON an.IdCompany = tblm.IdCompany AND tblm.IdTable = 1 AND tblm.IdColumn = an.IdStatus AND tblm.IdColumn > 0
INNER JOIN CompanyBranch cb ON cb.IdCompany = an.IdCompany AND cb.IdCompanyBranch = an.IdCompanyBranch
INNER JOIN Company com ON com.IdCompany = an.CreatedIdCompany
INNER JOIN [User] us1 ON us1.IdCompany = an.IdCompany AND us1.IdUser = an.CreatedIdUser
LEFT JOIN Company emp2 ON emp2.IdCompany = an.UpdatedIdCompany
LEFT JOIN [User] us2 ON us2.IdCompany = an.IdCompany AND us2.IdUser = an.UpdatedIdUser
WHERE an.IdCompany = @IdCompany 
AND (an.IdCompanyBranch = @IdCompanyBranch OR @IdCompanyBranch = 0)
AND an.DeletedFlag = 0
AND an.IdStatus = @IdStatus
AND an.IdReWeighing = @IdReWeighing
AND (ve.TruckNumber LIKE '%' + @Search + '%'
	OR ve.TrailerNumber LIKE '%' + @Search + '%'
	OR ca.CodCard LIKE '%' + @Search + '%'
	OR ca.DescriptionCard LIKE '%' + @Search + '%'
	OR @Search = ''
)

SELECT
an.IdCompany,
an.IdCompanyBranch,
an.IdReWeightVehicleCardId,
an.IdReWeighing,
an.IdVehicle,
ve.TruckNumber,
ve.TrailerNumber,
an.IdCardId,
ca.CodCard,
ca.IdStatus,
tblm.[Description] AS [Status],
com.CompanyName AS CreatedCompany,
us1.UserLogin AS CreatedUser,
CONVERT(VARCHAR(10), an.CreatedDate, 120) + ' ' + CONVERT(VARCHAR(8), DATEADD(MINUTE, @TimeZone, an.CreatedDate), 108) AS CreatedDate,
ISNULL(emp2.CompanyName, ' ') AS UpdatedCompany,
ISNULL(us2.UserLogin, ' ') AS UpdatedUser,
ISNULL(CONVERT(VARCHAR(10), an.UpdatedDate, 120) + ' ' + CONVERT(VARCHAR(8), DATEADD(MINUTE, @TimeZone, an.UpdatedDate), 108), ' ') AS UpdatedDate,
@TotalElements AS TotalElements 
FROM dbo.ReWeightVehicleCardId an
INNER JOIN dbo.Vehicle ve ON an.IdCompany = ve.IdCompany AND ve.IdVehicle = an.IdVehicle
INNER JOIN dbo.CardId ca ON an.IdCompany = ca.IdCompany AND an.IdCompanyBranch = ca.IdCompanyBranch AND ca.IdCard = an.IdCardId AND ca.DeletedFlag = 0
INNER JOIN MasterTable tblm ON an.IdCompany = tblm.IdCompany AND tblm.IdTable = 1 AND tblm.IdColumn = an.IdStatus AND tblm.IdColumn > 0
INNER JOIN CompanyBranch cb ON cb.IdCompany = an.IdCompany AND cb.IdCompanyBranch = an.IdCompanyBranch
INNER JOIN Company com ON com.IdCompany = an.CreatedIdCompany
INNER JOIN [User] us1 ON us1.IdCompany = an.IdCompany AND us1.IdUser = an.CreatedIdUser
LEFT JOIN Company emp2 ON emp2.IdCompany = an.UpdatedIdCompany
LEFT JOIN [User] us2 ON us2.IdCompany = an.IdCompany AND us2.IdUser = an.UpdatedIdUser
WHERE an.IdCompany = @IdCompany 
AND (an.IdCompanyBranch = @IdCompanyBranch OR @IdCompanyBranch = 0)
AND an.DeletedFlag = 0
AND an.IdStatus = @IdStatus
AND an.IdReWeighing = @IdReWeighing
AND (ve.TruckNumber LIKE '%' + @Search + '%'
	OR ve.TrailerNumber LIKE '%' + @Search + '%'
	OR ca.CodCard LIKE '%' + @Search + '%'
	OR ca.DescriptionCard LIKE '%' + @Search + '%'
	OR @Search = ''
)
ORDER BY IdReWeightVehicleCardId ASC
OFFSET @PageSize * (@PageIndex - 1) ROWS
FETCH NEXT @PageSize ROWS ONLY
