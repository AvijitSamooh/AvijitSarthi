import { Body, Controller, Delete, Get, Param, Post, Query, Req, UseGuards, Patch } from '@nestjs/common';
import { CityAdminGuard, type CityAdminRequest } from '../auth/city-admin.guard';
import { CityContentService } from './city-content.service';
import { CreateActivityDto } from './dto/create-activity.dto';
import { UpdateActivityDto } from './dto/update-activity.dto';

@Controller('admin/activities')
@UseGuards(CityAdminGuard)
export class AdminActivitiesController {
  constructor(private readonly content: CityContentService) {}
  @Get() list(@Req() req: CityAdminRequest, @Query('cityId') cityId?: string) { return this.content.list('activities', req.adminUser, cityId); }
  @Get(':id') get(@Param('id') id: string, @Req() req: CityAdminRequest) { return this.content.get('activities', id, req.adminUser); }
  @Post() create(@Body() dto: CreateActivityDto, @Req() req: CityAdminRequest) { return this.content.create('activities', dto, req.adminUser); }
  @Patch(':id') update(@Param('id') id: string, @Body() dto: UpdateActivityDto, @Req() req: CityAdminRequest) { return this.content.update('activities', id, dto, req.adminUser); }
  @Delete(':id') remove(@Param('id') id: string, @Req() req: CityAdminRequest) { return this.content.remove('activities', id, req.adminUser); }
}

@Controller('activities')
export class ActivitiesController {
  constructor(private readonly content: CityContentService) {}
  @Get() list(@Query('cityId') cityId?: string) { return this.content.list('activities', undefined, cityId); }
  @Get(':id') get(@Param('id') id: string) { return this.content.get('activities', id); }
}
