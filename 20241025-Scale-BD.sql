ALTER FUNCTION [dbo].[CustomCalculation] (@baseValue INT, @x INT)
RETURNS INT
AS
BEGIN
    DECLARE @result INT;

    IF @x < @baseValue
        --SET @result = @baseValue - @x;
        SET @result = @x;
    ELSE
        SET @result = ABS(@baseValue - @x) --/ 2;

    RETURN @result;
END;