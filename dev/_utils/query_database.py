import os
from sqlalchemy import create_engine, func
from sqlalchemy.orm import sessionmaker
from init_db import (
    Base, Company, Domain, Tool, DnsRecord, HttpResponse,
    Vuln, VulnClass, Evidence
)

# Build the connection string from environment variables
db_user = os.getenv("DB_USER")
db_password = os.getenv("DB_PASSWORD")
db_host = os.getenv("DB_HOST")
db_port = os.getenv("DB_PORT")
db_name = os.getenv("DB_NAME")

engine = create_engine(f'postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}')
Session = sessionmaker(bind=engine)
session = Session()

# ---------------------------
# Company CRUD Operations
# ---------------------------
def add_company(name, program_page=None, program_platform=None, can_hack=None, visibility=None):
    company = Company(
        name=name,
        program_page=program_page,
        program_platform=program_platform,
        can_hack=can_hack,
        visibility=visibility
    )
    session.add(company)
    session.commit()
    return company

def get_company(company_id):
    return session.query(Company).filter(Company.id == company_id).first()

def get_all_companies(limit=100):
    return session.query(Company).limit(limit).all()

def update_company(company_id, **kwargs):
    company = session.query(Company).filter(Company.id == company_id).first()
    if company:
        for key, value in kwargs.items():
            setattr(company, key, value)
        session.commit()
    return company

def delete_company(company_id):
    company = session.query(Company).filter(Company.id == company_id).first()
    if company:
        session.delete(company)
        session.commit()

# ---------------------------
# Domain CRUD Operations
# (Select/Get returns domains in random order)
# ---------------------------
def add_domain(name, level=None, type_=None, company_id=None, parent_domain_id=None,
               skip_scans=None, last_passive_enumeration=None, last_active_enumeration=None,
               last_probe=None, last_exploit=None):
    domain = Domain(
        name=name,
        level=level,
        type=type_,
        company_id=company_id,
        parent_domain_id=parent_domain_id,
        skip_scans=skip_scans,
        last_passive_enumeration=last_passive_enumeration,
        last_active_enumeration=last_active_enumeration,
        last_probe=last_probe,
        last_exploit=last_exploit
    )
    session.add(domain)
    session.commit()
    return domain

def get_domain(domain_id):
    return session.query(Domain).filter(Domain.id == domain_id).first()

def get_all_domains(limit=100):
    # Randomize the order of domains using PostgreSQL's random() function.
    return session.query(Domain).order_by(func.random()).limit(limit).all()

def update_domain(domain_id, **kwargs):
    domain = session.query(Domain).filter(Domain.id == domain_id).first()
    if domain:
        for key, value in kwargs.items():
            setattr(domain, key, value)
        session.commit()
    return domain

def delete_domain(domain_id):
    domain = session.query(Domain).filter(Domain.id == domain_id).first()
    if domain:
        session.delete(domain)
        session.commit()

# ---------------------------
# Tool CRUD Operations
# ---------------------------
def add_tool(name, type_=None):
    tool = Tool(name=name, type=type_)
    session.add(tool)
    session.commit()
    return tool

def get_tool(tool_id):
    return session.query(Tool).filter(Tool.id == tool_id).first()

def get_all_tools(limit=100):
    return session.query(Tool).limit(limit).all()

def update_tool(tool_id, **kwargs):
    tool = session.query(Tool).filter(Tool.id == tool_id).first()
    if tool:
        for key, value in kwargs.items():
            setattr(tool, key, value)
        session.commit()
    return tool

def delete_tool(tool_id):
    tool = session.query(Tool).filter(Tool.id == tool_id).first()
    if tool:
        session.delete(tool)
        session.commit()

# ---------------------------
# DnsRecord CRUD Operations
# ---------------------------
def add_dns_record(name, domain_id, type_=None, values=None):
    dns_record = DnsRecord(name=name, domain_id=domain_id, type=type_, values=values)
    session.add(dns_record)
    session.commit()
    return dns_record

def get_dns_record(record_id):
    return session.query(DnsRecord).filter(DnsRecord.id == record_id).first()

def get_all_dns_records(limit=100):
    return session.query(DnsRecord).limit(limit).all()

def update_dns_record(record_id, **kwargs):
    record = session.query(DnsRecord).filter(DnsRecord.id == record_id).first()
    if record:
        for key, value in kwargs.items():
            setattr(record, key, value)
        session.commit()
    return record

def delete_dns_record(record_id):
    record = session.query(DnsRecord).filter(DnsRecord.id == record_id).first()
    if record:
        session.delete(record)
        session.commit()

# ---------------------------
# HttpResponse CRUD Operations
# ---------------------------
def add_http_response(name, domain_id, url=None, scheme=None, method=None,
                      status_code=None, category=None, location=None,
                      content_type=None, content_length=None):
    http_response = HttpResponse(
        name=name,
        domain_id=domain_id,
        url=url,
        scheme=scheme,
        method=method,
        status_code=status_code,
        category=category,
        location=location,
        content_type=content_type,
        content_length=content_length
    )
    session.add(http_response)
    session.commit()
    return http_response

def get_http_response(response_id):
    return session.query(HttpResponse).filter(HttpResponse.id == response_id).first()

def get_all_http_responses(limit=100):
    return session.query(HttpResponse).limit(limit).all()

# ---------------------------
# Vuln CRUD Operations
# ---------------------------
def add_vuln(name, domain_id, title=None, vuln_class_id=None, description=None,
             severity=None, references=None, notified=None):
    vuln = Vuln(
        name=name,
        domain_id=domain_id,
        title=title,
        vuln_class_id=vuln_class_id,
        description=description,
        severity=severity,
        references=references,
        notified=notified
    )
    session.add(vuln)
    session.commit()
    return vuln

def get_vuln(vuln_id):
    return session.query(Vuln).filter(Vuln.id == vuln_id).first()

def get_all_vulns(limit=100):
    return session.query(Vuln).limit(limit).all()

# ---------------------------
# VulnClass CRUD Operations
# ---------------------------
def add_vuln_class(name):
    vuln_class = VulnClass(name=name)
    session.add(vuln_class)
    session.commit()
    return vuln_class

def get_vuln_class(vuln_class_id):
    return session.query(VulnClass).filter(VulnClass.id == vuln_class_id).first()

def get_all_vuln_classes(limit=100):
    return session.query(VulnClass).limit(limit).all()

# ---------------------------
# Evidence CRUD Operations
# ---------------------------
def add_evidence(vuln_id, target=None, request=None, response=None):
    evidence = Evidence(
        vuln_id=vuln_id,
        target=target,
        request=request,
        response=response
    )
    session.add(evidence)
    session.commit()
    return evidence

def get_evidence(evidence_id):
    return session.query(Evidence).filter(Evidence.id == evidence_id).first()

def get_all_evidences(limit=100):
    return session.query(Evidence).limit(limit).all()
