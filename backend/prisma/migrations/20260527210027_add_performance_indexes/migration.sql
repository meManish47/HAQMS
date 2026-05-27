-- CreateIndex
CREATE INDEX "Appointment_doctorId_status_idx" ON "Appointment"("doctorId", "status");

-- CreateIndex
CREATE INDEX "Appointment_patientId_idx" ON "Appointment"("patientId");

-- CreateIndex
CREATE INDEX "Appointment_appointmentDate_idx" ON "Appointment"("appointmentDate");

-- CreateIndex
CREATE INDEX "Doctor_specialization_idx" ON "Doctor"("specialization");

-- CreateIndex
CREATE INDEX "Doctor_department_idx" ON "Doctor"("department");

-- CreateIndex
CREATE INDEX "QueueToken_doctorId_createdAt_idx" ON "QueueToken"("doctorId", "createdAt");

-- CreateIndex
CREATE INDEX "QueueToken_status_idx" ON "QueueToken"("status");

-- CreateIndex
CREATE INDEX "QueueToken_doctorId_tokenNumber_idx" ON "QueueToken"("doctorId", "tokenNumber");
