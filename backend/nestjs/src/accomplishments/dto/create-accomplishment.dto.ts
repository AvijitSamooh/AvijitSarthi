import { ArrayUnique, IsArray, IsDateString, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateAccomplishmentDto {
  @IsString() @MinLength(1) @MaxLength(120) title!: string;
  @IsString() @MinLength(1) @MaxLength(10000) description!: string;
  @IsString() @MinLength(1) @MaxLength(80) cityId!: string;
  @IsDateString() achievedAt!: string;
  @IsOptional() @IsArray() @ArrayUnique() @IsString({ each: true }) organisationIds?: string[];
}
