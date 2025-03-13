import os
from sqlalchemy import (
    create_engine, Column, Integer, String, Boolean, DateTime, ForeignKey,
    Table, Text, ARRAY, Index, func
)
from sqlalchemy.orm import relationship, backref, declarative_base
from _utils._log import log

Base = declarative_base()

# --- Association Tables for Many-to-Many Relationships ---
domain_tool_association = Table(
    'domain_tool', Base.metadata,
    Column('domain_id', Integer, ForeignKey('domain.id'), primary_key=True),
    Column('tool_id', Integer, ForeignKey('tool.id'), primary_key=True)
)

vuln_tool_association = Table(
    'vuln_tool', Base.metadata,
    Column('vuln_id', Integer, ForeignKey('vuln.id'), primary_key=True),
    Column('tool_id', Integer, ForeignKey('tool.id'), primary_key=True)
)

# --- Models ---

class Company(Base):
    __tablename__ = 'company'
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, unique=True, nullable=False, index=True)
    program_page = Column(String)
    program_platform = Column(String, index=True)
    can_hack = Column(Boolean, index=True)
    visibility = Column(String, index=True)
    domains = relationship("Domain", back_populates="company")
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

class Domain(Base):
    __tablename__ = 'domain'
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, unique=True, nullable=False, index=True)
    level = Column(Integer, index=True)
    type = Column(String, index=True)
    company_id = Column(Integer, ForeignKey('company.id'), index=True)
    company = relationship("Company", back_populates="domains")
    parent_domain_id = Column(Integer, ForeignKey('domain.id'), nullable=True, index=True)
    subdomains = relationship("Domain", backref=backref('parent_domain', remote_side=[id]))
    skip_scans = Column(Boolean, index=True)
    last_passive_enumeration = Column(DateTime, index=True)
    last_active_enumeration = Column(DateTime, index=True)
    last_probe = Column(DateTime, index=True)
    last_exploit = Column(DateTime, index=True)
    found_by = relationship("Tool", secondary=domain_tool_association, back_populates="subdomains")
    dns_records = relationship("DnsRecord", back_populates="domain")
    http_responses = relationship("HttpResponse", back_populates="domain")
    vulns = relationship("Vuln", back_populates="domain")
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

class Tool(Base):
    __tablename__ = 'tool'
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, unique=True, nullable=False, index=True)
    type = Column(String, index=True)
    subdomains = relationship("Domain", secondary=domain_tool_association, back_populates="found_by")
    vulns = relationship("Vuln", secondary=vuln_tool_association, back_populates="found_by")
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

class DnsRecord(Base):
    __tablename__ = 'dns_record'
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, unique=True, nullable=False, index=True)
    domain_id = Column(Integer, ForeignKey('domain.id'), index=True)
    domain = relationship("Domain", back_populates="dns_records")
    type = Column(String, index=True)
    values = Column(ARRAY(String))
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

# Create a GIN index for the array column (if needed)
Index('idx_dnsrecord_values', DnsRecord.values, postgresql_using="gin")

class HttpResponse(Base):
    __tablename__ = 'http_response'
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, unique=True, nullable=False, index=True)
    domain_id = Column(Integer, ForeignKey('domain.id'), index=True)
    domain = relationship("Domain", back_populates="http_responses")
    url = Column(String, index=True)
    scheme = Column(String, index=True)
    method = Column(String, index=True)
    status_code = Column(Integer, index=True)
    category = Column(String, index=True)
    location = Column(String, index=True)
    content_type = Column(String, index=True)
    content_length = Column(Integer, index=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

class Vuln(Base):
    __tablename__ = 'vuln'
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, unique=True, nullable=False, index=True)
    domain_id = Column(Integer, ForeignKey('domain.id'), index=True)
    domain = relationship("Domain", back_populates="vulns")
    title = Column(String, index=True)
    vuln_class_id = Column(Integer, ForeignKey('vuln_class.id'), index=True)
    vuln_class = relationship("VulnClass", back_populates="vulns")
    description = Column(Text)
    severity = Column(String, index=True)
    references = Column(ARRAY(String))
    evidence = relationship("Evidence", uselist=False, back_populates="vuln")
    found_by = relationship("Tool", secondary=vuln_tool_association, back_populates="vulns")
    notified = Column(Boolean, index=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

class VulnClass(Base):
    __tablename__ = 'vuln_class'
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, unique=True, nullable=False, index=True)
    vulns = relationship("Vuln", back_populates="vuln_class")
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

class Evidence(Base):
    __tablename__ = 'evidence'
    id = Column(Integer, primary_key=True, autoincrement=True)
    vuln_id = Column(Integer, ForeignKey('vuln.id'), unique=True, index=True)
    vuln = relationship("Vuln", back_populates="evidence")
    target = Column(String)
    request = Column(Text)
    response = Column(Text)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

# --- Database Connection Using Environment Variables ---
DB_URI = os.getenv("DB_URI")
engine = create_engine(DB_URI)

def init_db():
    Base.metadata.create_all(engine)
    log('info', 'none', 'Database schema created')

if __name__ == '__main__':
    init_db()
