import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AuthenticatedRequest } from '../auth/auth.types';
import { DonationsService } from './donations.service';

@Controller('donations')
@UseGuards(FirebaseAuthGuard)
export class DonationsController {
  constructor(private readonly service: DonationsService) {}

  @Get('mine')
  listMine(@Req() request: Request & AuthenticatedRequest) {
    return this.service.listMine(request.user);
  }

  @Get('mine/:id')
  findMine(@Req() request: Request & AuthenticatedRequest, @Param('id') id: string) {
    return this.service.findMine(request.user, id);
  }

  @Post('mine/:id/receipt')
  issueReceipt(
    @Req() request: Request & AuthenticatedRequest,
    @Param('id') id: string,
    @Body('language') language?: string,
  ) {
    return this.service.issueReceipt(request.user, id, language);
  }

  @Get('mine/:id/receipt')
  findReceipt(@Req() request: Request & AuthenticatedRequest, @Param('id') id: string) {
    return this.service.findReceipt(request.user, id);
  }
}
