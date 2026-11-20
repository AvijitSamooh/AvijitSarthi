import { Body, Controller, Delete, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { CityAdminGuard, type CityAdminRequest } from '../auth/city-admin.guard';
import { CityContentService } from '../activities/city-content.service';
import { CreateAccomplishmentDto } from './dto/create-accomplishment.dto';
import { UpdateAccomplishmentDto } from './dto/update-accomplishment.dto';

@Controller('admin/accomplishments')
@UseGuards(CityAdminGuard)
export class AdminAccomplishmentsController {
  constructor(private readonly content: CityContentService) {}
  @Get() list(@Req() req: CityAdminRequest, @Query('cityId') cityId?: string) { return this.content.list('accomplishments', req.adminUser, cityId); }
  @Get(':id') get(@Param('id') id: string, @Req() req: CityAdminRequest) { return this.content.get('accomplishments', id, req.adminUser); }
  @Post() create(@Body() dto: CreateAccomplishmentDto, @Req() req: CityAdminRequest) { return this.content.create('accomplishments', dto, req.adminUser); }
  @Patch(':id') update(@Param('id') id: string, @Body() dto: UpdateAccomplishmentDto, @Req() req: CityAdminRequest) { return this.content.update('accomplishments', id, dto, req.adminUser); }
  @Delete(':id') remove(@Param('id') id: string, @Req() req: CityAdminRequest) { return this.content.remove('accomplishments', id, req.adminUser); }
}

@Controller('accomplishments')
export class AccomplishmentsController {
  constructor(private readonly content: CityContentService) {}
  @Get() list(@Query('cityId') cityId?: string) { return this.content.list('accomplishments', undefined, cityId); }
  @Get(':id') get(@Param('id') id: string) { return this.content.get('accomplishments', id); }
}
